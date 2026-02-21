import CoreImage
import CoreVideo
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "WebcamCompositor")

struct BubbleLayout: Sendable {
    /// Normalized X position (0 = left edge, 1 = right edge) of the bubble center.
    var normalizedX: CGFloat
    /// Normalized Y position (0 = bottom edge, 1 = top edge) of the bubble center.
    var normalizedY: CGFloat
    /// Bubble diameter in points (will be doubled for Retina pixels).
    var diameterPoints: CGFloat

    static let `default` = BubbleLayout(normalizedX: 0.1, normalizedY: 0.1, diameterPoints: 180)
}

private struct SendablePixelBuffer: @unchecked Sendable {
    var buffer: CVPixelBuffer?
}

final class WebcamCompositor: @unchecked Sendable {
    let borderWidth: CGFloat

    private let latestFrame: OSAllocatedUnfairLock<SendablePixelBuffer>
    private let latestLayout: OSAllocatedUnfairLock<BubbleLayout>
    private let ciContext: CIContext

    init(borderWidth: CGFloat = 3.0) {
        self.borderWidth = borderWidth
        self.latestFrame = OSAllocatedUnfairLock(initialState: SendablePixelBuffer(buffer: nil))
        self.latestLayout = OSAllocatedUnfairLock(initialState: .default)

        if let device = MTLCreateSystemDefaultDevice() {
            self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
        } else {
            self.ciContext = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
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

    /// Composites the latest webcam frame as a circular bubble onto the screen buffer.
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
        let diameter = layout.diameterPoints * 2 // Retina-scale

        let screenImage = CIImage(cvPixelBuffer: screenBuffer)
        let webcamImage = CIImage(cvPixelBuffer: webcamFrame)

        // Scale webcam to fit bubble diameter
        let webcamWidth = CGFloat(CVPixelBufferGetWidth(webcamFrame))
        let webcamHeight = CGFloat(CVPixelBufferGetHeight(webcamFrame))
        let scaleFactor = diameter / min(webcamWidth, webcamHeight)

        // Flip horizontally to unmirror the front camera + scale in one step
        let scaledWebcam = webcamImage
            .transformed(by: CGAffineTransform(scaleX: -scaleFactor, y: scaleFactor))
            .transformed(by: CGAffineTransform(translationX: webcamWidth * scaleFactor, y: 0))

        // Center-crop the scaled webcam to a square
        let scaledW = webcamWidth * scaleFactor
        let scaledH = webcamHeight * scaleFactor
        let cropOriginX = (scaledW - diameter) / 2.0
        let cropOriginY = (scaledH - diameter) / 2.0
        let croppedWebcam = scaledWebcam.cropped(to: CGRect(
            x: cropOriginX, y: cropOriginY,
            width: diameter, height: diameter
        ))

        // Create circular mask
        let radius = diameter / 2.0
        let centerX = cropOriginX + radius
        let centerY = cropOriginY + radius

        guard let maskImage = makeCircleMask(
            center: CGPoint(x: centerX, y: centerY),
            radius: radius,
            extent: croppedWebcam.extent
        ) else { return nil }

        // Apply circular mask to webcam
        let maskedWebcam = croppedWebcam.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.clear.cropped(to: croppedWebcam.extent),
            kCIInputMaskImageKey: maskImage,
        ])

        // Calculate bubble position from normalized layout
        // normalizedX/Y refer to the bubble center
        let bubbleCenterX = layout.normalizedX * CGFloat(screenWidth)
        let bubbleCenterY = layout.normalizedY * CGFloat(screenHeight)
        let bubbleOriginX = bubbleCenterX - radius
        let bubbleOriginY = bubbleCenterY - radius

        // Clamp to screen bounds
        let clampedX = max(0, min(bubbleOriginX, CGFloat(screenWidth) - diameter))
        let clampedY = max(0, min(bubbleOriginY, CGFloat(screenHeight) - diameter))

        // Translate masked webcam to bubble position
        let translateX = clampedX - cropOriginX
        let translateY = clampedY - cropOriginY
        let translation = CGAffineTransform(translationX: translateX, y: translateY)

        let positionedWebcam = maskedWebcam.transformed(by: translation)

        // Composite: webcam on top of screen
        let finalImage = positionedWebcam.composited(over: screenImage)

        // Render to output buffer from pool
        var outputBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, bufferPool, &outputBuffer)
        guard status == kCVReturnSuccess, let output = outputBuffer else {
            logger.error("Failed to create pixel buffer from pool: \(status)")
            return nil
        }

        let outputExtent = CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight)
        ciContext.render(finalImage, to: output, bounds: outputExtent, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)

        return output
    }

    // MARK: - Private

    private func makeCircleMask(center: CGPoint, radius: CGFloat, extent: CGRect) -> CIImage? {
        guard let filter = CIFilter(name: "CIRadialGradient") else { return nil }
        filter.setValue(CIVector(x: center.x, y: center.y), forKey: "inputCenter")
        filter.setValue(radius - 1, forKey: "inputRadius0")
        filter.setValue(radius, forKey: "inputRadius1")
        filter.setValue(CIColor.white, forKey: "inputColor0")
        filter.setValue(CIColor.clear, forKey: "inputColor1")
        return filter.outputImage?.cropped(to: extent)
    }
}
