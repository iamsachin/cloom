import AVFoundation
import CoreImage
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "WebcamRecordingService")
private let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

final class WebcamRecordingService: NSObject, @unchecked Sendable {
    // Properties accessed from capture queue — protected by isRecording flag
    nonisolated(unsafe) var imageAdjuster: WebcamImageAdjuster?
    nonisolated(unsafe) var personSegmenter: PersonSegmenter?
    nonisolated(unsafe) var micGainProcessor: MicGainProcessor?

    private let outputQueue = DispatchQueue(label: "com.cloom.webcamRecording", qos: .userInteractive)
    private let ciContext: CIContext

    private nonisolated(unsafe) var session: AVCaptureSession?
    private nonisolated(unsafe) var assetWriter: AVAssetWriter?
    private nonisolated(unsafe) var videoInput: AVAssetWriterInput?
    private nonisolated(unsafe) var audioInput: AVAssetWriterInput?
    private nonisolated(unsafe) var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private nonisolated(unsafe) var isRecording = false
    private nonisolated(unsafe) var sessionStarted = false

    /// Callback for preview frames (called on capture queue, dispatch to MainActor yourself)
    nonisolated(unsafe) var onPreviewFrame: ((_ image: CIImage, _ pixelBuffer: CVPixelBuffer) -> Void)?

    override init() {
        if let device = MTLCreateSystemDefaultDevice() {
            self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: sRGBColorSpace])
        } else {
            self.ciContext = CIContext(options: [.workingColorSpace: sRGBColorSpace])
        }
        super.init()
    }

    @MainActor
    func startRecording(
        outputURL: URL,
        cameraDeviceID: String?,
        micEnabled: Bool,
        micDeviceID: String?
    ) async throws {
        let session = AVCaptureSession()
        session.sessionPreset = .hd1280x720

        // Camera input
        let camera: AVCaptureDevice?
        if let id = cameraDeviceID {
            camera = AVCaptureDevice(uniqueID: id)
        } else {
            camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
        }
        guard let camera else {
            throw NSError(domain: "WebcamRecording", code: -1, userInfo: [NSLocalizedDescriptionKey: "No camera device available"])
        }

        let cameraInput = try AVCaptureDeviceInput(device: camera)
        if session.canAddInput(cameraInput) {
            session.addInput(cameraInput)
        }

        // Video output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        // Microphone input + audio output
        if micEnabled {
            let mic: AVCaptureDevice?
            if let id = micDeviceID {
                mic = AVCaptureDevice(uniqueID: id)
            } else {
                mic = AVCaptureDevice.default(for: .audio)
            }
            if let mic {
                let micInput = try AVCaptureDeviceInput(device: mic)
                if session.canAddInput(micInput) {
                    session.addInput(micInput)
                }

                let audioOutput = AVCaptureAudioDataOutput()
                audioOutput.setSampleBufferDelegate(self, queue: outputQueue)
                if session.canAddOutput(audioOutput) {
                    session.addOutput(audioOutput)
                }
            }
        }

        // Asset writer
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: 1280,
            AVVideoHeightKey: 720,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000,
                AVVideoExpectedSourceFrameRateKey: 30,
            ] as [String: Any]
        ]
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true
        writer.add(vInput)
        self.videoInput = vInput

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: vInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 1280,
                kCVPixelBufferHeightKey as String: 720,
            ]
        )
        self.pixelBufferAdaptor = adaptor

        if micEnabled {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128000,
            ]
            let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            aInput.expectsMediaDataInRealTime = true
            writer.add(aInput)
            self.audioInput = aInput
        }

        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "WebcamRecording", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to start writing"])
        }

        self.assetWriter = writer
        self.session = session
        self.isRecording = true
        self.sessionStarted = false

        session.startRunning()
        logger.info("Webcam-only recording started")
    }

    @MainActor
    func stopRecording() async {
        isRecording = false
        session?.stopRunning()
        session = nil

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        if let writer = assetWriter {
            await writer.finishWriting()
            if writer.status == .failed {
                logger.error("Webcam recording writer failed: \(writer.error?.localizedDescription ?? "unknown")")
            }
        }

        assetWriter = nil
        videoInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil
        onPreviewFrame = nil
        logger.info("Webcam-only recording stopped")
    }
}

// MARK: - Capture Delegate

extension WebcamRecordingService: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording, let writer = assetWriter, writer.status == .writing else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if !sessionStarted {
            writer.startSession(atSourceTime: timestamp)
            sessionStarted = true
        }

        if output is AVCaptureVideoDataOutput {
            guard let videoInput, videoInput.isReadyForMoreMediaData else { return }
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            var image = CIImage(cvPixelBuffer: pixelBuffer)

            // Apply image adjustments
            if let adjuster = imageAdjuster {
                image = adjuster.apply(to: image)
            }

            // Apply background blur
            if let segmenter = personSegmenter, segmenter.isEnabled {
                image = segmenter.process(image: image, pixelBuffer: pixelBuffer)
            }

            // Send preview frame
            onPreviewFrame?(image, pixelBuffer)

            // Flip horizontally (mirror)
            let flipped = image.transformed(by: CGAffineTransform(scaleX: -1, y: 1)
                .translatedBy(x: -image.extent.width, y: 0))

            // Render processed image back to a pixel buffer
            if let pool = pixelBufferAdaptor?.pixelBufferPool {
                var outputBuffer: CVPixelBuffer?
                let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outputBuffer)
                if status == kCVReturnSuccess, let outBuf = outputBuffer {
                    ciContext.render(flipped, to: outBuf, bounds: flipped.extent, colorSpace: sRGBColorSpace)
                    pixelBufferAdaptor?.append(outBuf, withPresentationTime: timestamp)
                }
            }
        } else if output is AVCaptureAudioDataOutput {
            guard let audioInput, audioInput.isReadyForMoreMediaData else { return }
            if let gainProc = micGainProcessor {
                let gained = gainProc.process(sampleBuffer)
                audioInput.append(gained)
            } else {
                audioInput.append(sampleBuffer)
            }
        }
    }
}
