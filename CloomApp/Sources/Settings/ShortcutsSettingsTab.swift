import SwiftUI
import Carbon.HIToolbox

struct ShortcutsSettingsTab: View {
    var body: some View {
        Form {
            ForEach(HotkeyAction.allCases, id: \.rawValue) { action in
                HStack {
                    Text(action.label)
                    Spacer()
                    ShortcutRecorderButton(action: action)
                }
            }

            Button("Reset to Defaults") {
                GlobalHotkeyManager.shared.resetToDefaults()
            }
            .font(.caption)
        }
        .formStyle(.grouped)
    }
}

// MARK: - Hotkey Action Labels

extension HotkeyAction {
    var label: String {
        switch self {
        case .toggleRecording: "Start / Stop Recording"
        case .togglePause: "Pause / Resume"
        }
    }
}

// MARK: - Shortcut Recorder Button

struct ShortcutRecorderButton: View {
    let action: HotkeyAction
    @State private var isRecording = false
    @State private var monitor: Any?

    private var binding: HotkeyBinding? {
        GlobalHotkeyManager.shared.bindings[action]
    }

    var body: some View {
        Button {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            if isRecording {
                Text("Press shortcut...")
                    .foregroundStyle(.orange)
                    .frame(minWidth: 120)
            } else {
                Text(binding?.displayString ?? "None")
                    .frame(minWidth: 120)
            }
        }
        .buttonStyle(.bordered)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        GlobalHotkeyManager.shared.stop()

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = event.keyCode
            let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
                .intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate])

            if keyCode == 53 {
                stopRecording()
                return nil
            }

            guard flags.rawValue != 0 else { return nil }

            let newBinding = HotkeyBinding(keyCode: keyCode, modifiers: flags.rawValue)
            GlobalHotkeyManager.shared.updateBinding(action: action, binding: newBinding)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
        GlobalHotkeyManager.shared.start()
    }
}
