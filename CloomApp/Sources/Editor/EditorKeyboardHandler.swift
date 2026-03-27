import AppKit
import SwiftUI

/// Monitors keyboard events at the window level for editor shortcuts.
/// Uses NSEvent.addLocalMonitorForEvents so shortcuts work regardless of focus.
struct EditorKeyboardModifier: ViewModifier {
    let state: EditorState
    @Binding var cutMarkInMs: Int64?

    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear { installMonitor() }
            .onDisappear { removeMonitor() }
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if handleKey(event) { return nil }  // consumed
            return event  // pass through
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    @MainActor
    private func handleKey(_ event: NSEvent) -> Bool {
        // Don't intercept if a text field has focus
        if let responder = NSApp.keyWindow?.firstResponder,
           responder is NSTextView || responder is NSTextField {
            return false
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasCmd = flags.contains(.command)
        let hasShift = flags.contains(.shift)
        let noModifiers = flags.isEmpty

        // Special keys by keyCode
        switch event.keyCode {
        case 123 where noModifiers: // Left arrow
            state.nudgeBackward()
            return true
        case 124 where noModifiers: // Right arrow
            state.nudgeForward()
            return true
        case 115: // Home
            state.seekTo(ms: state.edl.trimStartMs)
            return true
        case 119: // End
            let trimEnd = state.edl.trimEndMs > 0 ? state.edl.trimEndMs : state.durationMs
            state.seekTo(ms: trimEnd)
            return true
        default:
            break
        }

        // Character keys
        guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return false }

        switch chars {
        case "z" where hasCmd && hasShift:
            state.redo()
            return true
        case "z" where hasCmd:
            state.undo()
            return true
        case " " where noModifiers:
            state.togglePlayPause()
            return true
        case "j" where noModifiers:
            state.shuttleBackward()
            return true
        case "k" where noModifiers:
            state.shuttleStop()
            return true
        case "l" where noModifiers:
            state.shuttleForward()
            return true
        case "b" where noModifiers:
            state.addBookmark(ms: state.currentTimeMs)
            return true
        case "i" where noModifiers:
            cutMarkInMs = state.currentTimeMs
            return true
        case "o" where noModifiers:
            if let markIn = cutMarkInMs, markIn < state.currentTimeMs {
                state.addCut(startMs: markIn, endMs: state.currentTimeMs)
                cutMarkInMs = nil
            }
            return true
        default:
            return false
        }
    }
}

extension View {
    func editorKeyboardShortcuts(state: EditorState, cutMarkInMs: Binding<Int64?>) -> some View {
        modifier(EditorKeyboardModifier(state: state, cutMarkInMs: cutMarkInMs))
    }
}
