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

    private let store: AnnotationStore
    private let screenFrame: CGRect

    // In-progress stroke state
    private var activePoints: [StrokePoint] = []
    private var shapeOrigin: CGPoint?
    private var shapeEndpoint: CGPoint?
    private var isDrawing: Bool = false

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

    // MARK: - Coordinate conversion

    /// Convert view point to normalized (0-1) coordinates relative to screen.
    private func normalize(_ point: NSPoint) -> CGPoint {
        CGPoint(
            x: (point.x - screenFrame.origin.x) / screenFrame.width,
            y: (point.y - screenFrame.origin.y) / screenFrame.height
        )
    }

    /// Convert view point to pixel coordinates for the video buffer (assumes 2x Retina).
    private func toPixel(_ point: NSPoint) -> StrokePoint {
        let norm = normalize(point)
        // Store as pixel coordinates in the video buffer space
        // The renderer will use these directly
        return StrokePoint(x: norm.x * screenFrame.width * 2, y: norm.y * screenFrame.height * 2)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)

        switch currentTool {
        case .eraser:
            eraseAt(loc)

        case .pen, .highlighter:
            isDrawing = true
            activePoints = [toPixel(loc)]

        case .arrow, .line, .rectangle, .ellipse:
            isDrawing = true
            shapeOrigin = normalize(loc)
            shapeEndpoint = normalize(loc)
            activePoints = []
        }

        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)

        switch currentTool {
        case .eraser:
            eraseAt(loc)

        case .pen, .highlighter:
            guard isDrawing else { return }
            activePoints.append(toPixel(loc))
            // Push in-progress stroke to store so renderer burns it into video in real-time
            store.setActiveStroke(AnnotationStroke(
                tool: currentTool,
                color: currentColor,
                lineWidth: currentLineWidth,
                points: activePoints
            ))

        case .arrow, .line, .rectangle, .ellipse:
            guard isDrawing else { return }
            shapeEndpoint = normalize(loc)
            // Push in-progress shape to store
            if let origin = shapeOrigin {
                store.setActiveStroke(AnnotationStroke(
                    tool: currentTool,
                    color: currentColor,
                    lineWidth: currentLineWidth,
                    origin: origin,
                    endpoint: normalize(loc)
                ))
            }
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)

        guard isDrawing else { return }
        isDrawing = false

        switch currentTool {
        case .pen, .highlighter:
            activePoints.append(toPixel(loc))
            guard activePoints.count >= 2 else {
                activePoints = []
                return
            }
            let stroke = AnnotationStroke(
                tool: currentTool,
                color: currentColor,
                lineWidth: currentLineWidth,
                points: activePoints
            )
            store.addStroke(stroke)
            activePoints = []

        case .arrow, .line, .rectangle, .ellipse:
            shapeEndpoint = normalize(loc)
            guard let origin = shapeOrigin, let endpoint = shapeEndpoint else {
                resetShapeState()
                return
            }
            let stroke = AnnotationStroke(
                tool: currentTool,
                color: currentColor,
                lineWidth: currentLineWidth,
                origin: origin,
                endpoint: endpoint
            )
            store.addStroke(stroke)
            resetShapeState()

        case .eraser:
            break
        }

        needsDisplay = true
    }

    private func resetShapeState() {
        shapeOrigin = nil
        shapeEndpoint = nil
        activePoints = []
    }

    // MARK: - Eraser

    private func eraseAt(_ loc: NSPoint) {
        let norm = normalize(loc)
        // Create a small rect around the cursor position in pixel space
        let eraserSize: CGFloat = 20.0 / screenFrame.width
        let eraseRect = CGRect(
            x: (norm.x - eraserSize / 2) * screenFrame.width * 2,
            y: (norm.y - eraserSize / 2) * screenFrame.height * 2,
            width: eraserSize * screenFrame.width * 2,
            height: eraserSize * screenFrame.height * 2
        )
        store.eraseStrokes(intersecting: eraseRect)
        needsDisplay = true
    }

    // MARK: - Drawing (on-screen preview)

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Clear
        ctx.clear(bounds)

        // Draw committed strokes from store
        let snap = store.snapshot()
        for stroke in snap.strokes {
            drawStroke(stroke, in: ctx)
        }

        // Draw in-progress stroke
        if isDrawing {
            switch currentTool {
            case .pen, .highlighter:
                drawActiveFreePath(in: ctx)
            case .arrow, .line, .rectangle, .ellipse:
                drawActiveShape(in: ctx)
            default:
                break
            }
        }

        // Draw eraser cursor
        if currentTool == .eraser {
            let mouseLocation = NSEvent.mouseLocation
            let localPoint = convert(mouseLocation, from: nil)
            let size: CGFloat = 20
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.8).cgColor)
            ctx.setLineWidth(1.5)
            ctx.strokeEllipse(in: CGRect(x: localPoint.x - size/2, y: localPoint.y - size/2, width: size, height: size))
        }
    }

    private func drawStroke(_ stroke: AnnotationStroke, in ctx: CGContext) {
        let color = NSColor(
            srgbRed: stroke.color.r, green: stroke.color.g,
            blue: stroke.color.b, alpha: stroke.color.a
        )

        switch stroke.tool {
        case .pen:
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(stroke.lineWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            drawPointsAsViewPath(stroke.points, in: ctx)

        case .highlighter:
            let hlColor = color.withAlphaComponent(0.35)
            ctx.setStrokeColor(hlColor.cgColor)
            ctx.setLineWidth(stroke.lineWidth * 3)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            drawPointsAsViewPath(stroke.points, in: ctx)

        case .arrow:
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(stroke.lineWidth)
            ctx.setLineCap(.round)
            if let origin = stroke.origin, let endpoint = stroke.endpoint {
                let p1 = viewPoint(from: origin)
                let p2 = viewPoint(from: endpoint)
                ctx.beginPath()
                ctx.move(to: p1)
                ctx.addLine(to: p2)
                ctx.strokePath()
                drawArrowhead(ctx: ctx, from: p1, to: p2, lineWidth: stroke.lineWidth)
            }

        case .line:
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(stroke.lineWidth)
            ctx.setLineCap(.round)
            if let origin = stroke.origin, let endpoint = stroke.endpoint {
                ctx.beginPath()
                ctx.move(to: viewPoint(from: origin))
                ctx.addLine(to: viewPoint(from: endpoint))
                ctx.strokePath()
            }

        case .rectangle:
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(stroke.lineWidth)
            if let origin = stroke.origin, let endpoint = stroke.endpoint {
                let p1 = viewPoint(from: origin)
                let p2 = viewPoint(from: endpoint)
                let rect = CGRect(
                    x: min(p1.x, p2.x), y: min(p1.y, p2.y),
                    width: abs(p2.x - p1.x), height: abs(p2.y - p1.y)
                )
                ctx.stroke(rect)
            }

        case .ellipse:
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(stroke.lineWidth)
            if let origin = stroke.origin, let endpoint = stroke.endpoint {
                let p1 = viewPoint(from: origin)
                let p2 = viewPoint(from: endpoint)
                let rect = CGRect(
                    x: min(p1.x, p2.x), y: min(p1.y, p2.y),
                    width: abs(p2.x - p1.x), height: abs(p2.y - p1.y)
                )
                ctx.strokeEllipse(in: rect)
            }

        case .eraser:
            break
        }
    }

    /// Convert pixel-space stroke points to view coordinates for on-screen preview.
    private func drawPointsAsViewPath(_ points: [StrokePoint], in ctx: CGContext) {
        guard points.count >= 2 else { return }
        ctx.beginPath()
        let first = viewPointFromPixel(points[0])
        ctx.move(to: first)
        for i in 1..<points.count {
            ctx.addLine(to: viewPointFromPixel(points[i]))
        }
        ctx.strokePath()
    }

    /// Convert pixel coordinates back to view coordinates (inverse of toPixel).
    private func viewPointFromPixel(_ point: StrokePoint) -> CGPoint {
        let normX = point.x / (screenFrame.width * 2)
        let normY = point.y / (screenFrame.height * 2)
        return CGPoint(
            x: screenFrame.origin.x + normX * screenFrame.width,
            y: screenFrame.origin.y + normY * screenFrame.height
        )
    }

    /// Convert normalized (0-1) point to view coordinates.
    private func viewPoint(from normalized: CGPoint) -> CGPoint {
        CGPoint(
            x: screenFrame.origin.x + normalized.x * screenFrame.width,
            y: screenFrame.origin.y + normalized.y * screenFrame.height
        )
    }

    // MARK: - In-progress drawing

    private func drawActiveFreePath(in ctx: CGContext) {
        guard activePoints.count >= 2 else { return }
        let color = NSColor(
            srgbRed: currentColor.r, green: currentColor.g,
            blue: currentColor.b, alpha: currentTool == .highlighter ? 0.35 : currentColor.a
        )
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(currentTool == .highlighter ? currentLineWidth * 3 : currentLineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        drawPointsAsViewPath(activePoints, in: ctx)
    }

    private func drawActiveShape(in ctx: CGContext) {
        guard let origin = shapeOrigin, let endpoint = shapeEndpoint else { return }
        let color = NSColor(
            srgbRed: currentColor.r, green: currentColor.g,
            blue: currentColor.b, alpha: currentColor.a
        )
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(currentLineWidth)
        ctx.setLineCap(.round)

        let p1 = viewPoint(from: origin)
        let p2 = viewPoint(from: endpoint)

        switch currentTool {
        case .line:
            ctx.beginPath()
            ctx.move(to: p1)
            ctx.addLine(to: p2)
            ctx.strokePath()

        case .arrow:
            ctx.beginPath()
            ctx.move(to: p1)
            ctx.addLine(to: p2)
            ctx.strokePath()
            drawArrowhead(ctx: ctx, from: p1, to: p2, lineWidth: currentLineWidth)

        case .rectangle:
            let rect = CGRect(
                x: min(p1.x, p2.x), y: min(p1.y, p2.y),
                width: abs(p2.x - p1.x), height: abs(p2.y - p1.y)
            )
            ctx.stroke(rect)

        case .ellipse:
            let rect = CGRect(
                x: min(p1.x, p2.x), y: min(p1.y, p2.y),
                width: abs(p2.x - p1.x), height: abs(p2.y - p1.y)
            )
            ctx.strokeEllipse(in: rect)

        default:
            break
        }
    }

    private func drawArrowhead(ctx: CGContext, from p1: CGPoint, to p2: CGPoint, lineWidth: CGFloat) {
        let angle = atan2(p2.y - p1.y, p2.x - p1.x)
        let arrowLength = max(lineWidth * 4, 12)
        let arrowAngle: CGFloat = .pi / 6

        let tip1 = CGPoint(
            x: p2.x - arrowLength * cos(angle - arrowAngle),
            y: p2.y - arrowLength * sin(angle - arrowAngle)
        )
        let tip2 = CGPoint(
            x: p2.x - arrowLength * cos(angle + arrowAngle),
            y: p2.y - arrowLength * sin(angle + arrowAngle)
        )

        ctx.beginPath()
        ctx.move(to: p2)
        ctx.addLine(to: tip1)
        ctx.move(to: p2)
        ctx.addLine(to: tip2)
        ctx.strokePath()
    }
}
