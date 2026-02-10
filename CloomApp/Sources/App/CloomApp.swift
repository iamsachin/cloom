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

        Button("Start Recording") {
            // Phase 1B
        }
        .keyboardShortcut("r", modifiers: [.command, .shift])

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
}
