@preconcurrency import ScreenCaptureKit
import CoreVideo
import CoreImage
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ScreenCaptureService")
private let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

private struct SendableCVBuffer: @unchecked Sendable {
    let buffer: CVPixelBuffer
}

private struct SendableSampleBuffer: @unchecked Sendable {
    let buffer: CMSampleBuffer
}

// MARK: - SCStreamOutput

extension ScreenCaptureService: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard CMSampleBufferIsValid(sampleBuffer) else { return }

        switch type {
        case .screen:
            handleScreenFrame(sampleBuffer)
        case .audio:
            handleAudio(sampleBuffer, sourceType: .system)
        case .microphone:
            handleAudio(sampleBuffer, sourceType: .microphone)
        @unknown default:
            break
        }
    }

    nonisolated private func handleScreenFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        guard let writer = videoWriter else { return }

        // Step 1: Composite webcam if available
        let afterWebcam: CVPixelBuffer
        if let comp = compositor, let pool = bufferPool,
           let composited = comp.composite(screenBuffer: pixelBuffer, bufferPool: pool) {
            afterWebcam = composited
        } else {
            afterWebcam = pixelBuffer
        }

        // Step 2: Composite annotations if available
        let outputBuffer: CVPixelBuffer
        if let renderer = annotationRenderer, let pool = bufferPool {
            let screenWidth = CVPixelBufferGetWidth(afterWebcam)
            let screenHeight = CVPixelBufferGetHeight(afterWebcam)
            let currentTime = ProcessInfo.processInfo.systemUptime

            if let annotationOverlay = renderer.render(screenWidth: screenWidth, screenHeight: screenHeight, currentTime: currentTime) {
                let base = CIImage(cvPixelBuffer: afterWebcam)
                let final = annotationOverlay.composited(over: base)

                var poolBuffer: CVPixelBuffer?
                let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &poolBuffer)
                if status == kCVReturnSuccess, let output = poolBuffer {
                    let extent = CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight)
                    renderer.ciContext.render(final, to: output, bounds: extent, colorSpace: sRGBColorSpace)
                    outputBuffer = output
                } else {
                    outputBuffer = afterWebcam
                }
            } else {
                outputBuffer = afterWebcam
            }
        } else {
            outputBuffer = afterWebcam
        }

        let wrapped = SendableCVBuffer(buffer: outputBuffer)
        Task { await writer.appendVideo(wrapped.buffer, pts: pts) }
    }

    nonisolated private func handleAudio(_ sampleBuffer: CMSampleBuffer, sourceType: AudioSourceType) {
        guard let writer = videoWriter else { return }

        let processedBuffer: CMSampleBuffer
        if sourceType == .microphone, let processor = noiseCancellationProcessor {
            processedBuffer = processor.process(sampleBuffer)
        } else {
            processedBuffer = sampleBuffer
        }

        let wrapped = SendableSampleBuffer(buffer: processedBuffer)
        let source = sourceType
        Task { await writer.appendAudio(wrapped.buffer, sourceType: source) }
    }
}

// MARK: - SCStreamDelegate

extension ScreenCaptureService: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        logger.error("SCStream stopped with error: \(error)")
        Task { @MainActor in
            delegate?.captureDidFail(error: error)
        }
    }
}
