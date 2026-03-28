import Foundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "RecordingCoordinator")

// MARK: - Teleprompter Controls

extension RecordingCoordinator {

    func toggleTeleprompter() {
        if teleprompterEnabled {
            dismissTeleprompter()
            return
        }

        // Always show script panel — each recording gets a fresh script choice
        showTeleprompterScriptPanel()
    }

    func toggleTeleprompterScroll() {
        teleprompterOverlay?.toggleScrolling()
    }

    func showTeleprompterScriptPanel() {
        let currentScript = UserDefaults.standard.string(forKey: UserDefaultsKeys.teleprompterScript) ?? ""
        if teleprompterScriptPanel == nil {
            teleprompterScriptPanel = TeleprompterScriptPanel()
        }
        teleprompterScriptPanel?.show(currentScript: currentScript) { [weak self] script in
            UserDefaults.standard.set(script, forKey: UserDefaultsKeys.teleprompterScript)
            self?.teleprompterEnabled = true
            self?.showTeleprompter()
        }
    }

    func showTeleprompter() {
        let defaults = UserDefaults.standard
        let script = defaults.string(forKey: UserDefaultsKeys.teleprompterScript) ?? ""
        guard !script.isEmpty else {
            logger.info("No teleprompter script set — skipping show")
            teleprompterEnabled = false
            return
        }

        let fontSize = CGFloat(defaults.double(forKey: UserDefaultsKeys.teleprompterFontSize))
        let scrollSpeed = CGFloat(defaults.double(forKey: UserDefaultsKeys.teleprompterScrollSpeed))
        let opacity = defaults.double(forKey: UserDefaultsKeys.teleprompterOpacity)
        let posRaw = defaults.string(forKey: UserDefaultsKeys.teleprompterPosition) ?? TeleprompterPosition.bottom.rawValue
        let position = TeleprompterPosition(rawValue: posRaw) ?? .bottom
        let mirror = defaults.bool(forKey: UserDefaultsKeys.teleprompterMirrorEnabled)

        if teleprompterOverlay == nil {
            teleprompterOverlay = TeleprompterOverlayWindow()
        }

        teleprompterOverlay?.show(
            script: script,
            fontSize: fontSize > 0 ? fontSize : 40,
            opacity: opacity > 0 ? opacity : 0.85,
            position: position,
            scrollSpeed: scrollSpeed > 0 ? scrollSpeed : 60,
            mirrorEnabled: mirror
        )
    }

    func dismissTeleprompter() {
        teleprompterOverlay?.dismiss()
        teleprompterScriptPanel?.dismiss()
        teleprompterEnabled = false
    }
}
