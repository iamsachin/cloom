import AppKit

// MARK: - Drawing & Rendering

extension AnnotationCanvasView {

    func drawCanvas(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

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

    func drawStroke(_ stroke: AnnotationStroke, in ctx: CGContext) {
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

        case .text:
            if let text = stroke.text, let origin = stroke.origin {
                let viewPos = viewPoint(from: origin)
                let fontSize = stroke.fontSize ?? AnnotationCanvasView.defaultFontSize
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
                    .foregroundColor: color
                ]
                (text as NSString).draw(at: CGPoint(x: viewPos.x, y: viewPos.y - fontSize / 2), withAttributes: attrs)
            }

        case .eraser:
            break
        }
    }

    func drawPointsAsViewPath(_ points: [StrokePoint], in ctx: CGContext) {
        guard points.count >= 2 else { return }
        ctx.beginPath()
        let first = viewPointFromPixel(points[0])
        ctx.move(to: first)
        for i in 1..<points.count {
            ctx.addLine(to: viewPointFromPixel(points[i]))
        }
        ctx.strokePath()
    }

    func drawActiveFreePath(in ctx: CGContext) {
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

    func drawActiveShape(in ctx: CGContext) {
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

    func drawArrowhead(ctx: CGContext, from p1: CGPoint, to p2: CGPoint, lineWidth: CGFloat) {
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
