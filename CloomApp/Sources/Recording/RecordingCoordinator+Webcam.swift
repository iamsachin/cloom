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
    }

    func stopWebcam() {
        cameraService?.stop()
        webcamBubble?.dismiss()
        bubbleControlPill?.dismiss()
        bubbleControlPill = nil
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
            brightness: Float(defaults.double(forKey: "webcamBrightness")),
            contrast: {
                let v = defaults.double(forKey: "webcamContrast")
                return v == 0 ? 1 : Float(v)
            }(),
            saturation: {
                let v = defaults.double(forKey: "webcamSaturation")
                return v == 0 ? 1 : Float(v)
            }(),
            highlights: {
                let v = defaults.double(forKey: "webcamHighlights")
                return v == 0 ? 1 : Float(v)
            }(),
            shadows: Float(defaults.double(forKey: "webcamShadows")),
            temperature: {
                let v = defaults.double(forKey: "webcamTemperature")
                return v == 0 ? 6500 : Float(v)
            }(),
            tint: Float(defaults.double(forKey: "webcamTint"))
        )
    }

    func getCaptureAreaScreenRect() -> CGRect {
        switch selectedMode {
        case .fullScreen(let displayID):
            for screen in NSScreen.screens {
                let key = NSDeviceDescriptionKey("NSScreenNumber")
                if let screenID = screen.deviceDescription[key] as? CGDirectDisplayID, screenID == displayID {
                    return screen.frame
                }
            }
            return NSScreen.main?.frame ?? .zero

        case .window:
            return NSScreen.main?.frame ?? .zero

        case .region(_, let rect):
            return rect

        case .webcamOnly:
            return NSScreen.main?.frame ?? .zero
        }
    }
}
