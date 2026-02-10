import SwiftUI
@preconcurrency import ScreenCaptureKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ContentPicker")

/// A SwiftUI view for selecting what to capture: display, window, or region.
struct ContentPickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var displays: [SCDisplay] = []
    @State private var windows: [SCWindow] = []
    @State private var selectedTab = 0
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose what to record")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    appState.cancelContentSelection()
                    dismissWindow(id: "contentPicker")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding()

            Picker("", selection: $selectedTab) {
                Text("Displays").tag(0)
                Text("Windows").tag(1)
                Text("Region").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Divider()
                .padding(.top, 8)

            if isLoading {
                Spacer()
                ProgressView("Loading available content...")
                Spacer()
            } else {
                switch selectedTab {
                case 0:
                    displayList
                case 1:
                    windowList
                case 2:
                    regionPrompt
                default:
                    EmptyView()
                }
            }
        }
        .frame(width: 480, height: 400)
        .task {
            await loadContent()
        }
    }

    // MARK: - Displays tab

    private var displayList: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 12) {
                ForEach(displays, id: \.displayID) { display in
                    Button {
                        selectDisplay(display)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "display")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("Display \(display.displayID)")
                                .font(.subheadline.weight(.medium))
                            Text("\(display.width)×\(display.height)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    // MARK: - Windows tab

    private var windowList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                if windows.isEmpty {
                    Text("No windows available")
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                } else {
                    ForEach(windows, id: \.windowID) { window in
                        Button {
                            selectWindow(window)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "macwindow")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(window.title ?? "Untitled")
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    if let appName = window.owningApplication?.applicationName {
                                        Text(appName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text("\(Int(window.frame.width))×\(Int(window.frame.height))")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Region tab

    private var regionPrompt: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "rectangle.dashed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Click and drag on screen to select a region")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Select Region") {
                dismissWindow(id: "contentPicker")
                appState.startRegionSelection()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
    }

    // MARK: - Data loading

    private func loadContent() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            displays = content.displays
            windows = content.windows.filter { window in
                window.frame.width >= 100 &&
                window.frame.height >= 100 &&
                window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier &&
                window.isOnScreen
            }
        } catch {
            logger.error("Failed to load shareable content: \(error)")
        }
        isLoading = false
    }

    // MARK: - Selection actions

    private func selectDisplay(_ display: SCDisplay) {
        appState.selectMode(.fullScreen(displayID: display.displayID))
        dismissWindow(id: "contentPicker")
    }

    private func selectWindow(_ window: SCWindow) {
        appState.selectMode(.window(windowID: window.windowID))
        dismissWindow(id: "contentPicker")
    }
}
