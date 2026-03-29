import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "BlurRegionCompositor")

/// Builds an AVVideoComposition that applies blur/redaction CIFilters
/// to specified regions of each frame based on time ranges.
enum BlurRegionCompositor {

    /// Creates a video composition that blurs specified regions per frame.
    /// Regions are time-aware: only active regions for the current frame time are applied.
    @available(macOS, deprecated: 26.0, message: "Migrate to AVVideoComposition.Configuration when API stabilizes")
    static func buildVideoComposition(
        for asset: AVAsset,
        regions: [BlurRegion],
        sourceSize: CGSize
    ) async throws -> AVMutableVideoComposition {
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw NSError(domain: "BlurRegionCompositor", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let size = naturalSize.width > 0 ? naturalSize : sourceSize

        let videoComposition = AVMutableVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { request in
                autoreleasepool {
                    let frameTimeMs = Int64(request.compositionTime.seconds * 1000)
                    var image = request.sourceImage

                    // Apply each active blur region
                    for region in regions where frameTimeMs >= region.startMs && frameTimeMs <= region.endMs {
                        image = applyBlur(to: image, region: region, videoSize: size)
                    }

                    request.finish(with: image, context: SharedCIContext.instance)
                }
            }
        )

        videoComposition.renderSize = size
        let frameRate = try await videoTrack.load(.nominalFrameRate)
        let fps = frameRate > 0 ? Int32(frameRate.rounded()) : 30
        videoComposition.frameDuration = CMTime(value: 1, timescale: fps)

        logger.info("Blur composition: \(regions.count) regions on \(size.width)x\(size.height)")

        return videoComposition
    }

    // MARK: - Per-Region Blur Application

    /// Applies a single blur region to the source image.
    /// Coordinates are normalized (0–1) and converted to pixel coordinates.
    /// CIImage uses bottom-left origin, so Y is flipped from screen-space.
    private static func applyBlur(
        to source: CIImage,
        region: BlurRegion,
        videoSize: CGSize
    ) -> CIImage {
        // Convert normalized rect to pixel coordinates (CIImage bottom-left origin)
        let pixelX = region.x * videoSize.width
        let pixelY = (1.0 - region.y - region.height) * videoSize.height
        let pixelW = region.width * videoSize.width
        let pixelH = region.height * videoSize.height
        let rect = CGRect(x: pixelX, y: pixelY, width: pixelW, height: pixelH)

        switch region.style {
        case .gaussian:
            return applyGaussianBlur(to: source, rect: rect)
        case .pixelate:
            return applyPixelate(to: source, rect: rect)
        case .blackBox:
            return applyBlackBox(to: source, rect: rect)
        }
    }

    private static func applyGaussianBlur(to source: CIImage, rect: CGRect) -> CIImage {
        let cropped = source.cropped(to: rect)
        let blurred = cropped
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 30.0])
            .cropped(to: rect)
        return blurred.composited(over: source)
    }

    private static func applyPixelate(to source: CIImage, rect: CGRect) -> CIImage {
        let cropped = source.cropped(to: rect)
        // Fixed 12px cell size — small enough to obscure text, large enough to be visible
        let pixelated = cropped
            .applyingFilter("CIPixellate", parameters: [
                kCIInputScaleKey: 12.0,
                kCIInputCenterKey: CIVector(x: rect.midX, y: rect.midY),
            ])
            .cropped(to: rect)
        return pixelated.composited(over: source)
    }

    private static func applyBlackBox(to source: CIImage, rect: CGRect) -> CIImage {
        let black = CIImage(color: .black).cropped(to: rect)
        return black.composited(over: source)
    }
}
