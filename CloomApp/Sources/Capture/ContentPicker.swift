import ScreenCaptureKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "SystemContentPicker")

/// Wraps Apple's SCContentSharingPicker to present a native content picker
/// that handles Screen Recording permissions automatically.
final class SystemContentPicker: NSObject, SCContentSharingPickerObserver, @unchecked Sendable {
    private var onFilterSelected: (@MainActor (SCContentFilter) -> Void)?
    private var onCancelled: (@MainActor () -> Void)?

    @MainActor
    func present(
        onFilterSelected: @escaping @MainActor (SCContentFilter) -> Void,
        onCancelled: @escaping @MainActor () -> Void
    ) {
        self.onFilterSelected = onFilterSelected
        self.onCancelled = onCancelled

        let picker = SCContentSharingPicker.shared

        var config = SCContentSharingPickerConfiguration()
        config.allowedPickerModes = [.singleWindow, .singleDisplay]
        if let bundleID = Bundle.main.bundleIdentifier {
            config.excludedBundleIDs = [bundleID]
        }
        picker.defaultConfiguration = config

        picker.add(self)
        picker.isActive = true
        picker.present()

        logger.info("System content picker presented")
    }

    @MainActor
    private func cleanup() {
        let picker = SCContentSharingPicker.shared
        picker.remove(self)
        picker.isActive = false
        onFilterSelected = nil
        onCancelled = nil
    }

    // MARK: - SCContentSharingPickerObserver

    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        logger.info("Content picker cancelled")
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.onCancelled?()
            self.cleanup()
        }
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        logger.info("Content picker selected filter")
        nonisolated(unsafe) let capturedFilter = filter
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.onFilterSelected?(capturedFilter)
            self.cleanup()
        }
    }

    func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        logger.error("Content picker failed to start: \(error)")
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.onCancelled?()
            self.cleanup()
        }
    }
}
