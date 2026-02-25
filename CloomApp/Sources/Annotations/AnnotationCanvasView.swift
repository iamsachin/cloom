import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "AnnotationCanvasView")

/// NSView that handles mouse events for drawing annotations.
/// Renders a live on-screen preview via draw(_:) while the canonical data lives in AnnotationStore
/// (which AnnotationRenderer reads for video burn-in).
class AnnotationCanvasView: NSView {
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
        if event.keyCode == 53 { // Escape
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
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
