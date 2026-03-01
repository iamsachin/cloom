import AppKit
import CoreImage

// MARK: - Webcam Management

extension RecordingCoordinator {

    func startWebcam() {
        let settings = RecordingSettings.fromDefaults()

        if cameraService == nil {
            cameraService = CameraService(deviceID: settings.cameraDeviceID)
        }
        if blurEnabled && personSegmenter == nil {
            personSegmenter = PersonSegmenter()
            personSegmenter?.isEnabled = true
        }
        if webcamBubble == nil {
            webcamBubble = WebcamBubbleWindow()
        }

        let adjuster = WebcamImageAdjuster(adjustments: loadWebcamAdjustments())
        self.imageAdjuster = adjuster
        compositor?.imageAdjuster = adjuster

        webcamBubble?.onLayoutChanged = { [weak self] layout in
            self?.compositor?.updateBubbleLayout(layout)
        }

        cameraService?.onFrame = { [weak self] pixelBuffer, ciImage in
            guard let self else { return }
            self.compositor?.updateWebcamFrame(pixelBuffer)

            Task { @MainActor in
                self.handleCameraFrameForPreview(ciImage, pixelBuffer: pixelBuffer)
            }
        }
        cameraService?.start()
        webcamBubble?.show()
        startObservingWebcamSettings()
    }

    func stopWebcam() {
        stopObservingWebcamSettings()
        cameraService?.stop()
        webcamBubble?.dismiss()
        compositor = nil
        imageAdjuster = nil
    }

    func handleCameraFrameForPreview(_ image: CIImage, pixelBuffer: CVPixelBuffer) {
        var displayImage = image

        if let adjuster = imageAdjuster {
            displayImage = adjuster.apply(to: displayImage)
        }

        if blurEnabled, let segmenter = personSegmenter {
            displayImage = segmenter.process(image: displayImage, pixelBuffer: pixelBuffer)
        }

        webcamBubble?.updateFrame(displayImage)
    }

    func loadWebcamAdjustments() -> WebcamAdjustments {
        let defaults = UserDefaults.standard
        return WebcamAdjustments(
            brightness: Float(defaults.double(forKey: UserDefaultsKeys.webcamBrightness)),
            contrast: Float(defaults.object(forKey: UserDefaultsKeys.webcamContrast) as? Double ?? 1),
            saturation: Float(defaults.object(forKey: UserDefaultsKeys.webcamSaturation) as? Double ?? 1),
            highlights: Float(defaults.object(forKey: UserDefaultsKeys.webcamHighlights) as? Double ?? 1),
            shadows: Float(defaults.double(forKey: UserDefaultsKeys.webcamShadows)),
            temperature: Float(defaults.object(forKey: UserDefaultsKeys.webcamTemperature) as? Double ?? 6500),
            tint: Float(defaults.double(forKey: UserDefaultsKeys.webcamTint))
        )
    }

    // MARK: - Webcam Settings Observation

    private static let webcamSettingsKeys: Set<String> = [
        "webcamBrightness", "webcamContrast", "webcamSaturation",
        "webcamHighlights", "webcamShadows", "webcamTemperature", "webcamTint",
    ]

    func startObservingWebcamSettings() {
        stopObservingWebcamSettings()
        webcamSettingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.imageAdjuster?.updateAdjustments(self?.loadWebcamAdjustments() ?? .default)
            }
        }
    }

    func stopObservingWebcamSettings() {
        if let obs = webcamSettingsObserver {
            NotificationCenter.default.removeObserver(obs)
            webcamSettingsObserver = nil
        }
    }

    func getCaptureAreaScreenRect() -> CGRect {
        switch selectedMode {
        case .fullScreen(let displayID):
            return NSScreen.screen(for: displayID)?.frame ?? NSScreen.main?.frame ?? .zero

        case .window:
            return NSScreen.main?.frame ?? .zero

        case .region(_, let rect):
            return rect

        case .webcamOnly:
            return NSScreen.main?.frame ?? .zero
        }
    }
}
