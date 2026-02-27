import SwiftUI
import SwiftData
import UserNotifications

@main
struct CloomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var permissionChecker = PermissionChecker()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some Scene {
        MenuBarExtra("Cloom", image: "MenuBarIcon") {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(permissionChecker)
        }
        .menuBarExtraStyle(.menu)

        Window("Welcome to Cloom", id: "onboarding") {
            OnboardingView(permissionChecker: permissionChecker)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultLaunchBehavior(hasCompletedOnboarding && permissionChecker.requiredGranted ? .automatic : .presented)

        Window("Cloom Library", id: "library") {
            MainWindowView()
                .environmentObject(appState)
                .modelContainer(appState.modelContainer)
        }
        .defaultSize(width: 1100, height: 700)

        Settings {
            SettingsView()
                .environmentObject(permissionChecker)
        }
    }
}

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var permissionChecker: PermissionChecker
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @AppStorage("showPostOnboardingHint") private var showPostOnboardingHint: Bool = false

    var body: some View {
        if !permissionChecker.requiredGranted {
            Button("Complete Setup...") {
                NSApp.activate()
                openWindow(id: "onboarding")
            }

            Divider()
        }

        Button("Open Library") {
            NSApp.activate()
            openWindow(id: "library")
        }
        .keyboardShortcut("l", modifiers: [.command])

        Divider()

        if appState.recordingState.isIdle && permissionChecker.requiredGranted {
            if showPostOnboardingHint {
                Text("You're all set! Start your first recording below.")
                    .font(.caption)
            }

            Menu("Start Recording") {
                Button("Full Screen") {
                    showPostOnboardingHint = false
                    appState.startRecording()
                }

                Button("Choose Window or Display...") {
                    showPostOnboardingHint = false
                    appState.startRecordingWithPicker()
                }

                Button("Select Region...") {
                    showPostOnboardingHint = false
                    appState.recordingCoordinator.cancelContentSelection()
                    appState.recordingCoordinator.startRegionSelection()
                }

                Divider()

                Button("Webcam Only") {
                    showPostOnboardingHint = false
                    appState.startWebcamOnlyRecording()
                }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

        } else if appState.recordingState.isIdle && !permissionChecker.requiredGranted {
            Text("Start Recording")
                .foregroundStyle(.secondary)

        } else if appState.recordingState.isReady {
            Button("Start Recording") {
                appState.confirmRecording()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Cancel Setup") {
                appState.cancelReadyState()
            }

        } else if appState.recordingState.isRecording || appState.recordingState.isPaused {
            Button("Stop Recording") {
                appState.stopRecording()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            if appState.recordingState.isRecording {
                Button("Pause Recording") {
                    appState.pauseRecording()
                }
            } else {
                Button("Resume Recording") {
                    appState.resumeRecording()
                }
            }

            Divider()

            Button("Discard Recording") {
                appState.discardRecording()
            }
        } else {
            Text(menuStatusText)
                .font(.caption)
        }

        Divider()

        Text("Rust FFI: \(appState.rustGreeting)")
            .font(.caption)

        Text("Core v\(appState.rustVersion)")
            .font(.caption)

        Divider()

        Button("Settings...") {
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",", modifiers: [.command])

        Button("Quit Cloom") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var menuStatusText: String {
        switch appState.recordingState {
        case .ready: "Ready to record..."
        case .countdown(let n): "Starting in \(n)..."
        case .stopping: "Stopping..."
        case .selectingContent: "Selecting content..."
        case .paused: "Paused"
        default: ""
        }
    }
}

// MARK: - App Delegate (Notifications)

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Apply saved appearance mode
        let mode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        switch mode {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            break
        }

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Register "Open Library" action for recording-complete notifications
        let openAction = UNNotificationAction(identifier: "OPEN_LIBRARY", title: "Open Library")
        let category = UNNotificationCategory(
            identifier: "RECORDING_COMPLETE",
            actions: [openAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            NSApp.activate()
            if let window = NSApp.windows.first(where: { $0.title.contains("Library") }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
