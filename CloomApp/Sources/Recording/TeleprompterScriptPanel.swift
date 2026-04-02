import AppKit
import SwiftUI
import UniformTypeIdentifiers
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "TeleprompterScript")

/// Floating panel for entering/importing teleprompter script text before recording.
@MainActor
final class TeleprompterScriptPanel {
    private var panel: NSPanel?
    private var onDone: ((String) -> Void)?

    func show(currentScript: String, onDone: @escaping (String) -> Void) {
        self.onDone = onDone
        if panel == nil { createPanel() }
        guard let panel else { return }

        let view = TeleprompterScriptView(
            initialScript: currentScript,
            onSave: { [weak self] script in
                self?.onDone?(script)
                self?.dismiss()
            },
            onCancel: { [weak self] in
                self?.dismiss()
            }
        )
        let hostingView = NSHostingView(rootView: view)
        let size = NSSize(width: 480, height: 400)
        hostingView.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hostingView
        panel.setContentSize(size)

        if let screen = NSScreen.main {
            let x = screen.frame.midX - size.width / 2
            let y = screen.frame.midY - size.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.orderFrontRegardless()
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        onDone = nil
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Teleprompter Script"
        panel.level = NSWindow.Level(Int(CGShieldingWindowLevel()) + 1)
        panel.isOpaque = false
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = UserDefaults.standard.bool(forKey: UserDefaultsKeys.creatorModeEnabled) ? .readOnly : .none
        self.panel = panel
    }
}

// MARK: - SwiftUI View

struct TeleprompterScriptView: View {
    @State private var script: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    init(initialScript: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self._script = State(initialValue: initialScript)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Enter your script")
                .font(.headline)

            TextEditor(text: $script)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                )
                .frame(minHeight: 220)

            HStack {
                Button("Import File...") {
                    importFile()
                }

                Spacer()

                Text("\(wordCount) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)

                Button("Done") { onSave(script) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480, height: 400)
    }

    private var wordCount: Int {
        script.split(whereSeparator: \.isWhitespace).count
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "md") ?? .plainText]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        panel.level = NSWindow.Level(Int(CGShieldingWindowLevel()) + 2)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            script = content
            logger.info("Imported script from \(url.lastPathComponent)")
        } catch {
            logger.error("Failed to import script: \(error)")
        }
    }
}
