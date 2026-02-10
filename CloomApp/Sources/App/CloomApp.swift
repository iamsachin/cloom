import SwiftUI
import SwiftData

@main
struct CloomApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Cloom", systemImage: "record.circle") {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.menu)

        Window("Cloom Library", id: "library") {
            LibraryView()
                .environmentObject(appState)
                .modelContainer(appState.modelContainer)
        }
        .defaultSize(width: 900, height: 600)

        WindowGroup("Player", for: String.self) { $videoID in
            if let videoID {
                PlayerView(videoID: videoID)
                    .modelContainer(appState.modelContainer)
            }
        }
        .defaultSize(width: 800, height: 500)

        Settings {
            Text("Settings will go here")
                .frame(width: 400, height: 300)
        }
    }
}

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Library") {
            openWindow(id: "library")
        }
        .keyboardShortcut("l", modifiers: [.command])

        Divider()

        if appState.recordingState.isIdle {
            Button("Start Recording") {
                appState.startRecording()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        } else if appState.recordingState.isRecording {
            Button("Stop Recording") {
                appState.stopRecording()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
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

        Button("Quit Cloom") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var menuStatusText: String {
        switch appState.recordingState {
        case .countdown(let n): "Starting in \(n)..."
        case .stopping: "Stopping..."
        default: ""
        }
    }
}
