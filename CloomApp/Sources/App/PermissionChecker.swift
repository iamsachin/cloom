import SwiftUI
import AVFoundation
import CoreGraphics

enum PermissionKind: String, CaseIterable, Identifiable {
    case screenRecording
    case camera
    case microphone
    case accessibility

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .screenRecording: "Screen Recording"
        case .camera: "Camera"
        case .microphone: "Microphone"
        case .accessibility: "Accessibility"
        }
    }

    var description: String {
        switch self {
        case .screenRecording: "Captures your entire screen, a specific window, or a selected region so Cloom can create the recording."
        case .camera: "Shows your webcam as a floating bubble overlay on recordings — great for presentations and walkthroughs."
        case .microphone: "Records your voice narration and system audio so viewers can hear what you're explaining."
        case .accessibility: "Powers global keyboard shortcuts (start/stop/pause recording from anywhere) and click emphasis effects."
        }
    }

    var isOptional: Bool {
        self == .accessibility
    }

    var icon: String {
        switch self {
        case .screenRecording: "rectangle.dashed.badge.record"
        case .camera: "camera.fill"
        case .microphone: "mic.fill"
        case .accessibility: "accessibility"
        }
    }
}

@MainActor
final class PermissionChecker: ObservableObject {
    @Published var statuses: [PermissionKind: Bool] = [:]

    private var pollTimer: Timer?

    var allGranted: Bool {
        PermissionKind.allCases.allSatisfy { statuses[$0] == true }
    }

    var requiredGranted: Bool {
        PermissionKind.allCases
            .filter { !$0.isOptional }
            .allSatisfy { statuses[$0] == true }
    }

    init() {
        // Populate synchronously without publishing to avoid
        // "Publishing changes from within view updates" when
        // @StateObject initialises during body evaluation.
        for kind in PermissionKind.allCases {
            statuses[kind] = checkPermission(kind)
        }
    }

    // MARK: - Non-prompting checks

    func checkAll() {
        for kind in PermissionKind.allCases {
            statuses[kind] = checkPermission(kind)
        }
    }

    private func checkPermission(_ kind: PermissionKind) -> Bool {
        switch kind {
        case .screenRecording:
            return CGPreflightScreenCaptureAccess()
        case .camera:
            return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        case .microphone:
            return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        case .accessibility:
            return AXIsProcessTrusted()
        }
    }

    // MARK: - Grant actions

    func requestPermission(_ kind: PermissionKind) {
        switch kind {
        case .camera:
            requestAVPermission(for: .video)
        case .microphone:
            requestAVPermission(for: .audio)
        case .screenRecording:
            CGRequestScreenCaptureAccess()
        case .accessibility:
            // Open Accessibility pane directly — on debug rebuilds the code
            // signature changes so existing entries go stale; user needs to
            // toggle OFF → ON to re-authorize.
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func requestAVPermission(for mediaType: AVMediaType) {
        let status = AVCaptureDevice.authorizationStatus(for: mediaType)
        if status == .notDetermined {
            Task {
                await AVCaptureDevice.requestAccess(for: mediaType)
                checkAll()
            }
        } else if status == .denied || status == .restricted {
            openSystemSettings()
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Polling

    func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAll()
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
