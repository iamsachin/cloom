import AppKit

@MainActor
enum DiscardConfirmation {
    /// Shows a confirmation alert. Returns `true` if the user confirmed discard.
    static func show() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Discard Recording?"
        alert.informativeText = "This will stop the current recording and permanently delete it. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        // Make Discard button destructive appearance
        alert.buttons.first?.hasDestructiveAction = true
        return alert.runModal() == .alertFirstButtonReturn
    }
}
