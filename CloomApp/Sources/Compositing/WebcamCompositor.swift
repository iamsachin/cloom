import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import CoreGraphics
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "WebcamCompositor")
private let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

struct BubbleLayout: Sendable {
    var normalizedX: CGFloat
    var normalizedY: CGFloat
    var diameterPoints: CGFloat
    var shape: WebcamShape = .circle
    var decoration: WebcamFrame = .none

    static let `default` = BubbleLayout(normalizedX: 0.1, normalizedY: 0.1, diameterPoints: 180)
}

private struct SendablePixelBuffer: @unchecked Sendable {
    var buffer: CVPixelBuffer?
}

private struct SendableAdjuster: @unchecked Sendable {
    var adjuster: WebcamImageAdjuster?
}

final class WebcamCompositor: @unchecked Sendable {
    let borderWidth: CGFloat

    private let _imageAdjuster: OSAllocatedUnfairLock<SendableAdjuster>
    var imageAdjuster: WebcamImageAdjuster? {
        get { _imageAdjuster.withLock { $0.adjuster } }
        set { _imageAdjuster.withLock { $0.adjuster = newValue } }
    }

    private let latestFrame: OSAllocatedUnfairLock<SendablePixelBuffer>
    private let latestLayout: OSAllocatedUnfairLock<BubbleLayout>
    private let ciContext: CIContext = SharedCIContext.instance

    // Shape mask cache (accessed from extension)
    let maskCache: OSAllocatedUnfairLock<ShapeMaskCache>

    // Emoji frame cache (accessed from extension)
    let frameImageCache: OSAllocatedUnfairLock<FrameImageCache>

    init(borderWidth: CGFloat = 3.0) {
        self.borderWidth = borderWidth
        self._imageAdjuster = OSAllocatedUnfairLock(initialState: SendableAdjuster())
        self.latestFrame = OSAllocatedUnfairLock(initialState: SendablePixelBuffer(buffer: nil))
        self.latestLayout = OSAllocatedUnfairLock(initialState: .default)
        self.maskCache = OSAllocatedUnfairLock(initialState: ShapeMaskCache())
        self.frameImageCache = OSAllocatedUnfairLock(initialState: FrameImageCache())
    }

    func updateWebcamFrame(_ pixelBuffer: CVPixelBuffer) {
        let wrapped = SendablePixelBuffer(buffer: pixelBuffer)
        latestFrame.withLock { $0 = wrapped }
    }

    func updateBubbleLayout(_ layout: BubbleLayout) {
        latestLayout.withLock { $0 = layout }
    }

    func composite(screenBuffer: CVPixelBuffer, bufferPool: CVPixelBufferPool) -> CVPixelBuffer? {
        let wrapped: SendablePixelBuffer = latestFrame.withLock { $0 }
        guard let webcamFrame = wrapped.buffer else { return nil }

        let layout: BubbleLayout = latestLayout.withLock { $0 }

        let screenWidth = CVPixelBufferGetWidth(screenBuffer)
        let screenHeight = CVPixelBufferGetHeight(screenBuffer)

        let height = layout.diameterPoints * 2
        let width = height * layout.shape.aspectRatio

        let screenImage = CIImage(cvPixelBuffer: screenBuffer)
        var webcamImage = CIImage(cvPixelBuffer: webcamFrame)

        if let adjuster = imageAdjuster {
            webcamImage = adjuster.apply(to: webcamImage)
        }

        // Scale and flip webcam
        let webcamWidth = CGFloat(CVPixelBufferGetWidth(webcamFrame))
        let webcamHeight = CGFloat(CVPixelBufferGetHeight(webcamFrame))
        let scaleFactor = max(width / webcamWidth, height / webcamHeight)

        let scaledWebcam = webcamImage
            .transformed(by: CGAffineTransform(scaleX: -scaleFactor, y: scaleFactor))
            .transformed(by: CGAffineTransform(translationX: webcamWidth * scaleFactor, y: 0))

        // Center-crop
        let scaledW = webcamWidth * scaleFactor
        let scaledH = webcamHeight * scaleFactor
        let cropOriginX = (scaledW - width) / 2.0
        let cropOriginY = (scaledH - height) / 2.0
        let croppedWebcam = scaledWebcam.cropped(to: CGRect(
            x: cropOriginX, y: cropOriginY,
            width: width, height: height
        ))

        // Apply shape mask
        let maskExtent = croppedWebcam.extent
        guard let maskImage = makeShapeMask(shape: layout.shape, extent: maskExtent) else { return nil }

        let maskedWebcam = croppedWebcam.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.clear.cropped(to: maskExtent),
            kCIInputMaskImageKey: maskImage,
        ])

        // Position bubble
        let bubbleCenterX = layout.normalizedX * CGFloat(screenWidth)
        let bubbleCenterY = layout.normalizedY * CGFloat(screenHeight)
        let bubbleOriginX = bubbleCenterX - width / 2
        let bubbleOriginY = bubbleCenterY - height / 2

        let clampedX = max(0, min(bubbleOriginX, CGFloat(screenWidth) - width))
        let clampedY = max(0, min(bubbleOriginY, CGFloat(screenHeight) - height))

        let translateX = clampedX - cropOriginX
        let translateY = clampedY - cropOriginY
        let positionedWebcam = maskedWebcam.transformed(by: CGAffineTransform(translationX: translateX, y: translateY))

        // Webcam over screen
        var finalImage = positionedWebcam.composited(over: screenImage)

        // Emoji frame on top of everything
        if layout.decoration != .none {
            if let frameCIImage = cachedFrameImage(for: layout) {
                let pad = EmojiFrameRenderer.framePadding(for: min(width, height))
                let frameOriginX = clampedX - pad
                let frameOriginY = clampedY - pad
                let positioned = frameCIImage.transformed(
                    by: CGAffineTransform(translationX: frameOriginX, y: frameOriginY)
                )
                finalImage = positioned.composited(over: finalImage)
            }
        }

        // Render to pool buffer
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
}
