import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import CoreGraphics
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "WebcamCompositor")
private let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

struct BubbleLayout: Sendable {
    /// Normalized X position (0 = left edge, 1 = right edge) of the bubble center.
    var normalizedX: CGFloat
    /// Normalized Y position (0 = bottom edge, 1 = top edge) of the bubble center.
    var normalizedY: CGFloat
    /// Bubble diameter in points (will be doubled for Retina pixels).
    var diameterPoints: CGFloat
    /// Shape of the webcam bubble.
    var shape: WebcamShape = .circle
    /// Background theme for the bubble border.
    var theme: BubbleTheme = .none

    static let `default` = BubbleLayout(normalizedX: 0.1, normalizedY: 0.1, diameterPoints: 180)
}

private struct SendablePixelBuffer: @unchecked Sendable {
    var buffer: CVPixelBuffer?
}

final class WebcamCompositor: @unchecked Sendable {
    let borderWidth: CGFloat

    nonisolated(unsafe) var imageAdjuster: WebcamImageAdjuster?

    private let latestFrame: OSAllocatedUnfairLock<SendablePixelBuffer>
    private let latestLayout: OSAllocatedUnfairLock<BubbleLayout>
    private let ciContext: CIContext

    // Shape mask cache
    private let maskCache: OSAllocatedUnfairLock<ShapeMaskCache>

    init(borderWidth: CGFloat = 3.0) {
        self.borderWidth = borderWidth
        self.latestFrame = OSAllocatedUnfairLock(initialState: SendablePixelBuffer(buffer: nil))
        self.latestLayout = OSAllocatedUnfairLock(initialState: .default)
        self.maskCache = OSAllocatedUnfairLock(initialState: ShapeMaskCache())

        if let device = MTLCreateSystemDefaultDevice() {
            self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: sRGBColorSpace])
        } else {
            self.ciContext = CIContext(options: [.workingColorSpace: sRGBColorSpace])
        }
    }

    /// Called from CameraService's output queue — thread-safe.
    func updateWebcamFrame(_ pixelBuffer: CVPixelBuffer) {
        let wrapped = SendablePixelBuffer(buffer: pixelBuffer)
        latestFrame.withLock { $0 = wrapped }
    }

    /// Called from MainActor when the bubble window moves or resizes — thread-safe.
    func updateBubbleLayout(_ layout: BubbleLayout) {
        latestLayout.withLock { $0 = layout }
    }

    /// Composites the latest webcam frame onto the screen buffer.
    /// Called from SCStreamOutput queue. Returns a new CVPixelBuffer from the provided pool.
    func composite(screenBuffer: CVPixelBuffer, bufferPool: CVPixelBufferPool) -> CVPixelBuffer? {
        let wrapped: SendablePixelBuffer = latestFrame.withLock { $0 }
        let webcamFrame = wrapped.buffer
        guard let webcamFrame else {
            return nil
        }

        let layout: BubbleLayout = latestLayout.withLock { $0 }

        let screenWidth = CVPixelBufferGetWidth(screenBuffer)
        let screenHeight = CVPixelBufferGetHeight(screenBuffer)

        // Calculate shape dimensions at Retina scale
        let height = layout.diameterPoints * 2 // Retina-scale
        let width = height * layout.shape.aspectRatio

        let screenImage = CIImage(cvPixelBuffer: screenBuffer)
        var webcamImage = CIImage(cvPixelBuffer: webcamFrame)

        // Apply image adjustments if available
        if let adjuster = imageAdjuster {
            webcamImage = adjuster.apply(to: webcamImage)
        }

        // Scale webcam to fit bubble dimensions
        let webcamWidth = CGFloat(CVPixelBufferGetWidth(webcamFrame))
        let webcamHeight = CGFloat(CVPixelBufferGetHeight(webcamFrame))
        let scaleFactor = max(width, height) / min(webcamWidth, webcamHeight)

        // Flip horizontally to unmirror the front camera + scale in one step
        let scaledWebcam = webcamImage
            .transformed(by: CGAffineTransform(scaleX: -scaleFactor, y: scaleFactor))
            .transformed(by: CGAffineTransform(translationX: webcamWidth * scaleFactor, y: 0))

        // Center-crop the scaled webcam to shape dimensions
        let scaledW = webcamWidth * scaleFactor
        let scaledH = webcamHeight * scaleFactor
        let cropOriginX = (scaledW - width) / 2.0
        let cropOriginY = (scaledH - height) / 2.0
        let croppedWebcam = scaledWebcam.cropped(to: CGRect(
            x: cropOriginX, y: cropOriginY,
            width: width, height: height
        ))

        // Create shape mask
        let maskExtent = croppedWebcam.extent
        guard let maskImage = makeShapeMask(
            shape: layout.shape,
            extent: maskExtent
        ) else { return nil }

        // Apply mask to webcam
        let maskedWebcam = croppedWebcam.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.clear.cropped(to: maskExtent),
            kCIInputMaskImageKey: maskImage,
        ])

        // Calculate bubble position from normalized layout
        let bubbleCenterX = layout.normalizedX * CGFloat(screenWidth)
        let bubbleCenterY = layout.normalizedY * CGFloat(screenHeight)
        let bubbleOriginX = bubbleCenterX - width / 2
        let bubbleOriginY = bubbleCenterY - height / 2

        // Clamp to screen bounds
        let clampedX = max(0, min(bubbleOriginX, CGFloat(screenWidth) - width))
        let clampedY = max(0, min(bubbleOriginY, CGFloat(screenHeight) - height))

        // Translate masked webcam to bubble position
        let translateX = clampedX - cropOriginX
        let translateY = clampedY - cropOriginY
        let translation = CGAffineTransform(translationX: translateX, y: translateY)

        let positionedWebcam = maskedWebcam.transformed(by: translation)

        // Composite theme ring if needed
        var compositeBase = screenImage
        if layout.theme != .none {
            let themeBorderWidth: CGFloat = 6 * 2 // Retina scale (matches bubble's 6pt border)
            let themeWidth = width + themeBorderWidth * 2
            let themeHeight = height + themeBorderWidth * 2
            let themeOriginX = clampedX - themeBorderWidth
            let themeOriginY = clampedY - themeBorderWidth

            if let themeRing = makeThemeRing(
                theme: layout.theme,
                shape: layout.shape,
                size: CGSize(width: themeWidth, height: themeHeight),
                origin: CGPoint(x: themeOriginX, y: themeOriginY)
            ) {
                compositeBase = themeRing.composited(over: compositeBase)
            }
        }

        // Composite: webcam on top of screen (with optional theme ring)
        let finalImage = positionedWebcam.composited(over: compositeBase)

        // Render to output buffer from pool
        var outputBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, bufferPool, &outputBuffer)
        guard status == kCVReturnSuccess, let output = outputBuffer else {
            logger.error("Failed to create pixel buffer from pool: \(status)")
            return nil
        }

        let outputExtent = CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight)
        ciContext.render(finalImage, to: output, bounds: outputExtent, colorSpace: sRGBColorSpace)

        return output
    }

    // MARK: - Shape Masks

    private func makeShapeMask(shape: WebcamShape, extent: CGRect) -> CIImage? {
        switch shape {
        case .circle:
            return makeCircleMask(
                center: CGPoint(x: extent.midX, y: extent.midY),
                radius: extent.height / 2.0,
                extent: extent
            )
        case .roundedRect, .pill:
            return makeRoundedRectMask(shape: shape, extent: extent)
        }
    }

    private func makeCircleMask(center: CGPoint, radius: CGFloat, extent: CGRect) -> CIImage? {
        guard let filter = CIFilter(name: "CIRadialGradient") else { return nil }
        filter.setValue(CIVector(x: center.x, y: center.y), forKey: "inputCenter")
        filter.setValue(radius - 1, forKey: "inputRadius0")
        filter.setValue(radius, forKey: "inputRadius1")
        filter.setValue(CIColor.white, forKey: "inputColor0")
        filter.setValue(CIColor.clear, forKey: "inputColor1")
        return filter.outputImage?.cropped(to: extent)
    }

    private func makeRoundedRectMask(shape: WebcamShape, extent: CGRect) -> CIImage? {
        // Check cache first
        let cacheKey = ShapeMaskCache.Key(shape: shape, width: extent.width, height: extent.height)
        if let cached: CIImage = maskCache.withLock({ $0.get(cacheKey) }) {
            // Translate cached mask to match extent origin
            return cached.transformed(by: CGAffineTransform(translationX: extent.origin.x, y: extent.origin.y))
        }

        let width = Int(extent.width)
        let height = Int(extent.height)
        let cornerRadius = shape.cornerRadius(forHeight: extent.height)

        let colorSpace = sRGBColorSpace
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(path)
        ctx.fillPath()

        guard let cgImage = ctx.makeImage() else { return nil }
        let maskImage = CIImage(cgImage: cgImage)

        // Cache the mask at origin (0,0)
        maskCache.withLock { $0.set(cacheKey, value: maskImage) }

        return maskImage.transformed(by: CGAffineTransform(translationX: extent.origin.x, y: extent.origin.y))
    }

    // MARK: - Theme Ring

    private func makeThemeRing(theme: BubbleTheme, shape: WebcamShape, size: CGSize, origin: CGPoint) -> CIImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        let cornerRadius = shape.cornerRadius(forHeight: size.height)

        let colorSpace = sRGBColorSpace
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

        if let gradientColors = theme.gradientCGColors() {
            guard let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: [gradientColors.0, gradientColors.1] as CFArray,
                locations: [0, 1]
            ) else { return nil }
            ctx.addPath(path)
            ctx.clip()
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: CGFloat(height)),
                end: CGPoint(x: CGFloat(width), y: 0),
                options: []
            )
        } else if let solidColor = theme.cgColor() {
            ctx.setFillColor(solidColor)
            ctx.addPath(path)
            ctx.fillPath()
        } else {
            return nil
        }

        guard let cgImage = ctx.makeImage() else { return nil }
        return CIImage(cgImage: cgImage)
            .transformed(by: CGAffineTransform(translationX: origin.x, y: origin.y))
    }
}

// MARK: - Shape Mask Cache

private struct ShapeMaskCache {
    struct Key: Hashable {
        let shape: WebcamShape
        let width: CGFloat
        let height: CGFloat
    }

    private var cache: [Key: CIImage] = [:]

    func get(_ key: Key) -> CIImage? {
        cache[key]
    }

    mutating func set(_ key: Key, value: CIImage) {
        // Keep cache small — only store latest shape+size
        if cache.count > 3 {
            cache.removeAll()
        }
        cache[key] = value
    }
}
