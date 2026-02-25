import AppKit

/// Custom NSView that forwards clicks to a handler, distinguishing clicks from drags.
class BubbleContentView: NSView {
    var onClick: (() -> Void)?
    var onRightClick: (() -> Void)?
    /// Mouse-down position in screen coordinates (stable during window drag).
    private var mouseDownScreenLocation: NSPoint?

    override func mouseDown(with event: NSEvent) {
        // Record position in screen coordinates before the drag moves the window
        mouseDownScreenLocation = NSEvent.mouseLocation
        // Call super so isMovableByWindowBackground can initiate a drag
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        defer { mouseDownScreenLocation = nil }
        guard let downScreen = mouseDownScreenLocation else { return }
        // Compare in screen coordinates — immune to window movement
        let upScreen = NSEvent.mouseLocation
        let dx = upScreen.x - downScreen.x
        let dy = upScreen.y - downScreen.y
        let distance = sqrt(dx * dx + dy * dy)
        // Only treat as click if mouse moved less than 3pt on screen
        if distance < 3 {
            onClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }
}
