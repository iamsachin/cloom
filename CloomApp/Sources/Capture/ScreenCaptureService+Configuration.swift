@preconcurrency import ScreenCaptureKit
import AVFoundation

// MARK: - Filter Builder & Stream Configuration

extension ScreenCaptureService {

    func buildFilter(mode: CaptureMode, content: SCShareableContent, creatorMode: Bool = false) throws -> SCContentFilter {
        switch mode {
        case .fullScreen(let displayID):
            guard let display = content.displays.first(where: { $0.displayID == displayID })
                    ?? content.displays.first else {
                throw CaptureError.noDisplay
            }
            let excludedApps: [SCRunningApplication] = creatorMode ? [] : content.applications.filter {
                $0.bundleIdentifier == Bundle.main.bundleIdentifier
            }
            return SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])

        case .window(let windowID):
            guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
                throw CaptureError.noWindow
            }
            return SCContentFilter(desktopIndependentWindow: window)

        case .region(let displayID, _):
            guard let display = content.displays.first(where: { $0.displayID == displayID })
                    ?? content.displays.first else {
                throw CaptureError.noDisplay
            }
            let excludedApps: [SCRunningApplication] = creatorMode ? [] : content.applications.filter {
                $0.bundleIdentifier == Bundle.main.bundleIdentifier
            }
            return SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])

        }
    }

    func configureStream(_ config: SCStreamConfiguration, mode: CaptureMode, content: SCShareableContent) {
        let scaleFactor: Int

        switch mode {
        case .fullScreen(let displayID):
            let display = content.displays.first(where: { $0.displayID == displayID })
                ?? content.displays.first
            scaleFactor = display.map { screenScaleFactor(for: $0.displayID) } ?? 2
            config.width = (display?.width ?? 1920) * scaleFactor
            config.height = (display?.height ?? 1080) * scaleFactor

        case .window:
            scaleFactor = 2
            config.width = 1920 * scaleFactor
            config.height = 1080 * scaleFactor

        case .region(let displayID, let rect):
            scaleFactor = screenScaleFactor(for: displayID)
            config.sourceRect = rect
            config.width = Int(rect.width) * scaleFactor
            config.height = Int(rect.height) * scaleFactor
            config.destinationRect = CGRect(
                origin: .zero,
                size: CGSize(
                    width: CGFloat(config.width),
                    height: CGFloat(config.height)
                )
            )

        }
    }

    func configureCommon(_ config: SCStreamConfiguration, settings: RecordingSettings, micEnabled: Bool, systemAudioEnabled: Bool = true) {
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(settings.fps))
        config.showsCursor = true
        config.capturesAudio = systemAudioEnabled
        config.captureMicrophone = micEnabled
        if let micID = settings.micDeviceID {
            config.microphoneCaptureDeviceID = micID
        } else if let defaultMic = AVCaptureDevice.default(for: .audio) {
            config.microphoneCaptureDeviceID = defaultMic.uniqueID
        }
    }

    func screenScaleFactor(for displayID: CGDirectDisplayID) -> Int {
        if let screen = NSScreen.screen(for: displayID) {
            return Int(screen.backingScaleFactor)
        }
        return 2
    }
}

// MARK: - Errors

enum CaptureError: LocalizedError {
    case noDisplay
    case noWindow

    var errorDescription: String? {
        switch self {
        case .noDisplay: "No display found for screen capture."
        case .noWindow: "Selected window is no longer available."
        }
    }
}
