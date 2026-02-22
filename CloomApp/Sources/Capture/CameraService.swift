import AVFoundation
import CoreImage
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "CameraService")

final class CameraService: NSObject, @unchecked Sendable {
    var onFrame: ((_ pixelBuffer: CVPixelBuffer, _ image: CIImage) -> Void)?

    private var session: AVCaptureSession?
    private let outputQueue = DispatchQueue(label: "com.cloom.camera", qos: .userInteractive)
    private let preferredDeviceID: String?

    init(deviceID: String? = nil) {
        self.preferredDeviceID = deviceID
        super.init()
    }

    func start() {
        guard session == nil else { return }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.configureAndStart()
                    }
                } else {
                    logger.error("Camera access denied by user")
                }
            }
        default:
            logger.error("Camera access not authorized (status: \(status.rawValue))")
        }
    }

    func stop() {
        session?.stopRunning()
        session = nil
        onFrame = nil
        logger.info("Camera stopped")
    }

    static func availableCameras() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices
    }

    // MARK: - Private

    private func configureAndStart() {
        guard session == nil else { return }

        let session = AVCaptureSession()
        session.sessionPreset = .hd1280x720

        let device: AVCaptureDevice?
        if let id = preferredDeviceID {
            device = AVCaptureDevice(uniqueID: id)
        } else {
            device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
        }
        guard let device else {
            logger.error("No camera device available")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            logger.error("Failed to create camera input: \(error)")
            return
        }

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: outputQueue)

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        self.session = session
        session.startRunning()
        logger.info("Camera started (authorized)")
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        onFrame?(pixelBuffer, image)
    }
}
