import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ReframeCompositor")

/// Builds an AVVideoComposition that reframes video to a target aspect ratio
/// using per-frame CIImage crop, scale, and background fill.
enum ReframeCompositor {

    enum ReframeError: LocalizedError {
        case noVideoTrack
        case invalidSourceSize

        var errorDescription: String? {
            switch self {
            case .noVideoTrack: "No video track found in composition"
            case .invalidSourceSize: "Source video has invalid dimensions"
            }
        }
    }

    /// Creates a video composition that applies reframing to each frame.
    static func buildVideoComposition(
        for asset: AVAsset,
        config: ReframeConfig
    ) async throws -> AVVideoComposition {
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else { throw ReframeError.noVideoTrack }

        let naturalSize = try await videoTrack.load(.naturalSize)
        guard naturalSize.width > 0 && naturalSize.height > 0 else {
            throw ReframeError.invalidSourceSize
        }

        let sourceSize = naturalSize
        let outputSize = config.outputSize
        // Flip focusY from screen-space (top-left origin) to CIImage-space (bottom-left origin)
        let ciFocusY = 1.0 - config.focusY

        let crop = reframeCropRect(
            for: config.aspectRatio,
            in: sourceSize,
            focusX: config.focusX,
            focusY: ciFocusY
        )

        let frameRate = try await videoTrack.load(.nominalFrameRate)
        let fps = frameRate > 0 ? Int32(frameRate.rounded()) : 30

        // Create CI filter composition (auto-derives renderSize from asset)
        let ciComposition = try await AVVideoComposition(
            applyingFiltersTo: asset,
            applier: { params in
                let source = params.sourceImage

                let background = makeBackground(
                    from: source,
                    sourceSize: sourceSize,
                    outputSize: outputSize,
                    fillStyle: config.backgroundFill
                )

                let foreground = cropAndScale(
                    source,
                    cropRect: crop,
                    targetSize: outputSize
                )

                let composite = foreground.composited(over: background)
                let result = composite.cropped(to: CGRect(origin: .zero, size: outputSize))

                return AVCIImageFilteringResult(resultImage: result, ciContext: SharedCIContext.instance)
            }
        )

        // Rebuild with custom renderSize for the target aspect ratio
        let reframeConfig = AVVideoComposition.Configuration(
            customVideoCompositorClass: ciComposition.customVideoCompositorClass,
            frameDuration: CMTime(value: 1, timescale: fps),
            instructions: ciComposition.instructions,
            renderSize: outputSize
        )
        let videoComposition = AVVideoComposition(configuration: reframeConfig)

        logger.info(
            "Reframe: \(sourceSize.width)x\(sourceSize.height) → \(outputSize.width)x\(outputSize.height)"
        )

        return videoComposition
    }

    // MARK: - Per-Frame Helpers

    /// Crops source to `cropRect`, translates to origin, and scales to `targetSize`.
    static func cropAndScale(
        _ image: CIImage,
        cropRect: CGRect,
        targetSize: CGSize
    ) -> CIImage {
        let cropped = image.cropped(to: cropRect)
        let translated = cropped.transformed(
            by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y)
        )
        let scaleX = targetSize.width / cropRect.width
        let scaleY = targetSize.height / cropRect.height
        return translated.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }

    /// Builds the background layer for the given fill style, sized to `outputSize`.
    static func makeBackground(
        from source: CIImage,
        sourceSize: CGSize,
        outputSize: CGSize,
        fillStyle: BackgroundFillStyle
    ) -> CIImage {
        let outputRect = CGRect(origin: .zero, size: outputSize)

        switch fillStyle {
        case .solidColor(let r, let g, let b, let a):
            return CIImage(color: CIColor(red: r, green: g, blue: b, alpha: a))
                .cropped(to: outputRect)

        case .gradient(let tr, let tg, let tb, let br, let bg, let bb):
            let gradient = CIFilter.linearGradient()
            // CIImage: (0,0) = bottom, so point0 = bottom color, point1 = top color
            gradient.point0 = CGPoint(x: 0, y: 0)
            gradient.point1 = CGPoint(x: 0, y: outputSize.height)
            gradient.color0 = CIColor(red: br, green: bg, blue: bb)
            gradient.color1 = CIColor(red: tr, green: tg, blue: tb)
            return (gradient.outputImage ?? CIImage(color: .black)).cropped(to: outputRect)

        case .blur(let radius):
            let scaleX = outputSize.width / sourceSize.width
            let scaleY = outputSize.height / sourceSize.height
            let fillScale = max(scaleX, scaleY)

            let scaled = source.transformed(
                by: CGAffineTransform(scaleX: fillScale, y: fillScale)
            )

            let scaledW = sourceSize.width * fillScale
            let scaledH = sourceSize.height * fillScale
            let offsetX = (scaledW - outputSize.width) / 2.0
            let offsetY = (scaledH - outputSize.height) / 2.0
            let centered = scaled.transformed(
                by: CGAffineTransform(translationX: -offsetX, y: -offsetY)
            )

            // clampedToExtent prevents black edge artifacts from blur sampling
            let blurred = centered.clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
                .cropped(to: outputRect)

            return blurred
        }
    }

    // MARK: - Preview Rendering

    /// Renders a single-frame preview of the reframe for the export UI.
    /// Returns a CGImage suitable for display in SwiftUI.
    static func renderPreview(
        from sourceImage: CIImage,
        config: ReframeConfig,
        previewWidth: CGFloat = 300
    ) -> CGImage? {
        let sourceSize = sourceImage.extent.size
        guard sourceSize.width > 0 && sourceSize.height > 0 else { return nil }

        let scale = previewWidth / config.outputSize.width
        let previewSize = CGSize(
            width: config.outputSize.width * scale,
            height: config.outputSize.height * scale
        )

        let ciFocusY = 1.0 - config.focusY
        let crop = reframeCropRect(
            for: config.aspectRatio,
            in: sourceSize,
            focusX: config.focusX,
            focusY: ciFocusY
        )

        let background = makeBackground(
            from: sourceImage,
            sourceSize: sourceSize,
            outputSize: config.outputSize,
            fillStyle: config.backgroundFill
        )

        let foreground = cropAndScale(
            sourceImage,
            cropRect: crop,
            targetSize: config.outputSize
        )

        let composite = foreground.composited(over: background)
            .cropped(to: CGRect(origin: .zero, size: config.outputSize))

        let previewImage = composite.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        return SharedCIContext.instance.createCGImage(
            previewImage,
            from: CGRect(origin: .zero, size: previewSize)
        )
    }
}
