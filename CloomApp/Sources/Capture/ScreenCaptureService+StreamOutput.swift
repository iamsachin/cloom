@preconcurrency import ScreenCaptureKit
import CoreVideo
import CoreImage
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ScreenCaptureService")

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
        // Read all shared state in one lock acquisition
        let state = captureState.withLock { state -> CaptureState? in
            guard !state.isProcessingFrame else { return nil }
            state.isProcessingFrame = true
            return state
        }
        guard let state else { return }
        defer { captureState.withLock { $0.isProcessingFrame = false } }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        guard let writer = state.videoWriter else { return }

        // Creator Mode: SCStream captures panels directly — skip software compositing
        if state.creatorMode {
            let wrapped = SendableCVBuffer(buffer: pixelBuffer)
            Task { await writer.appendVideo(wrapped.buffer, pts: pts) }
            return
        }

        // Step 1: Composite webcam if available
        let afterWebcam: CVPixelBuffer
        if let comp = state.compositor, let pool = state.bufferPool,
           let composited = comp.composite(screenBuffer: pixelBuffer, bufferPool: pool) {
            afterWebcam = composited
        } else {
            afterWebcam = pixelBuffer
        }

        // Step 2: Composite annotations (before zoom so annotations get zoomed with content)
        let afterAnnotations: CVPixelBuffer
        if let renderer = state.annotationRenderer, let pool = state.bufferPool {
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
                    renderer.renderToBuffer(final, to: output, bounds: extent)
                    afterAnnotations = output
                } else {
                    afterAnnotations = afterWebcam
                }
            } else {
                afterAnnotations = afterWebcam
            }
        } else {
            afterAnnotations = afterWebcam
        }

        // Step 3: Apply zoom if active (after annotations so they zoom with content)
        let outputBuffer: CVPixelBuffer
        if let renderer = state.annotationRenderer, let pool = state.bufferPool {
            let zoomWidth = CVPixelBufferGetWidth(afterAnnotations)
            let zoomHeight = CVPixelBufferGetHeight(afterAnnotations)
            let zoomTime = ProcessInfo.processInfo.systemUptime

            if let zoomedImage = renderer.applyZoom(to: CIImage(cvPixelBuffer: afterAnnotations),
                                                     screenWidth: zoomWidth, screenHeight: zoomHeight,
                                                     currentTime: zoomTime) {
                var poolBuffer: CVPixelBuffer?
                let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &poolBuffer)
                if status == kCVReturnSuccess, let output = poolBuffer {
                    let extent = CGRect(x: 0, y: 0, width: zoomWidth, height: zoomHeight)
                    renderer.renderToBuffer(zoomedImage, to: output, bounds: extent)
                    outputBuffer = output
                } else {
                    outputBuffer = afterAnnotations
                }
            } else {
                outputBuffer = afterAnnotations
            }
        } else {
            outputBuffer = afterAnnotations
        }

        let wrapped = SendableCVBuffer(buffer: outputBuffer)
        Task { await writer.appendVideo(wrapped.buffer, pts: pts) }
    }

    nonisolated private func handleAudio(_ sampleBuffer: CMSampleBuffer, sourceType: AudioSourceType) {
        let (writer, gainProc) = captureState.withLock {
            ($0.videoWriter, $0.micGainProcessor)
        }
        guard let writer else { return }

        var processedBuffer = sampleBuffer

        if sourceType == .microphone, let gainProc {
            processedBuffer = gainProc.process(processedBuffer)
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
