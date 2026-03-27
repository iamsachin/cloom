import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "AnnotationCanvasView")

/// NSView that handles mouse events for drawing annotations.
/// Renders a live on-screen preview via draw(_:) while the canonical data lives in AnnotationStore
/// (which AnnotationRenderer reads for video burn-in).
class AnnotationCanvasView: NSView, NSTextFieldDelegate {
    var currentTool: AnnotationTool = .pen
    var currentColor: StrokeColor = .red
    var currentLineWidth: CGFloat = 3.0
    /// Called when Escape is pressed — used to exit draw mode.
    var onEscape: (() -> Void)?

    let store: AnnotationStore
    let screenFrame: CGRect

    // In-progress stroke state
    var activePoints: [StrokePoint] = []
    var shapeOrigin: CGPoint?
    var shapeEndpoint: CGPoint?
    var isDrawing: Bool = false

    // Text tool state
    var activeTextField: NSTextField?
    var textOriginNormalized: CGPoint?
    static let defaultFontSize: CGFloat = 24.0

    init(frame: NSRect, store: AnnotationStore, screenFrame: CGRect) {
        self.store = store
        self.screenFrame = screenFrame
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Don't intercept keys while text field is active
        if activeTextField != nil { return }
        if event.keyCode == 53 { // Escape
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Text Tool

    func placeTextField(at viewPoint: NSPoint) {
        commitActiveText()

        let normalized = normalize(viewPoint)
        textOriginNormalized = normalized

        let textField = NSTextField()
        textField.isBordered = false
        textField.drawsBackground = true
        textField.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        textField.isEditable = true
        textField.isSelectable = true
        textField.focusRingType = .none
        textField.font = NSFont.systemFont(ofSize: Self.defaultFontSize, weight: .medium)
        textField.textColor = NSColor(srgbRed: currentColor.r, green: currentColor.g,
                                       blue: currentColor.b, alpha: currentColor.a)
        textField.alignment = .left
        textField.placeholderString = "Type here..."
        textField.delegate = self
        textField.cell?.wraps = false
        textField.cell?.isScrollable = true
        textField.frame = NSRect(x: viewPoint.x, y: viewPoint.y - Self.defaultFontSize / 2,
                                  width: 300, height: Self.defaultFontSize + 10)
        textField.wantsLayer = true
        textField.layer?.cornerRadius = 4
        addSubview(textField)
        activeTextField = textField

        // Activate editing — selectText triggers the field editor which handles keyboard input
        DispatchQueue.main.async { [weak textField] in
            guard let textField else { return }
            textField.window?.makeFirstResponder(textField)
            textField.selectText(nil)
            // Move cursor to end (selectText selects all)
            textField.currentEditor()?.selectedRange = NSRange(location: 0, length: 0)
        }
    }

    func commitActiveText() {
        guard let textField = activeTextField, let origin = textOriginNormalized else {
            removeActiveTextField()
            return
        }
        let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            let stroke = AnnotationStroke(
                tool: .text,
                color: currentColor,
                lineWidth: currentLineWidth,
                origin: origin,
                text: text,
                fontSize: Self.defaultFontSize
            )
            store.addStroke(stroke)
        }
        removeActiveTextField()
        needsDisplay = true
    }

    func cancelActiveText() {
        removeActiveTextField()
    }

    private func removeActiveTextField() {
        activeTextField?.removeFromSuperview()
        activeTextField = nil
        textOriginNormalized = nil
        window?.makeFirstResponder(self)
    }

    // MARK: - NSTextFieldDelegate

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            commitActiveText()
            return true
        }
        if commandSelector == #selector(cancelOperation(_:)) {
            cancelActiveText()
            return true
        }
        return false
    }

    // MARK: - Coordinate Conversion

    /// Convert view point to normalized (0-1) coordinates relative to screen.
    func normalize(_ point: NSPoint) -> CGPoint {
        CGPoint(
            x: (point.x - screenFrame.origin.x) / screenFrame.width,
            y: (point.y - screenFrame.origin.y) / screenFrame.height
        )
    }

    /// Convert view point to pixel coordinates for the video buffer (assumes 2x Retina).
    func toPixel(_ point: NSPoint) -> StrokePoint {
        let norm = normalize(point)
        return StrokePoint(x: norm.x * screenFrame.width * 2, y: norm.y * screenFrame.height * 2)
    }

    /// Convert pixel coordinates back to view coordinates (inverse of toPixel).
    func viewPointFromPixel(_ point: StrokePoint) -> CGPoint {
        let normX = point.x / (screenFrame.width * 2)
        let normY = point.y / (screenFrame.height * 2)
        return CGPoint(
            x: screenFrame.origin.x + normX * screenFrame.width,
            y: screenFrame.origin.y + normY * screenFrame.height
        )
    }

    /// Convert normalized (0-1) point to view coordinates.
    func viewPoint(from normalized: CGPoint) -> CGPoint {
        CGPoint(
            x: screenFrame.origin.x + normalized.x * screenFrame.width,
            y: screenFrame.origin.y + normalized.y * screenFrame.height
        )
    }

    // MARK: - NSView Overrides

    override func mouseDown(with event: NSEvent) {
        handleMouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        handleMouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        handleMouseUp(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        drawCanvas(dirtyRect)
    }
}
