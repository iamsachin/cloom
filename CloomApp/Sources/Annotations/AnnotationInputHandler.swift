import AppKit

// MARK: - Mouse Input Handling

extension AnnotationCanvasView {

    func handleMouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)

        switch currentTool {
        case .eraser:
            eraseAt(loc)

        case .pen, .highlighter:
            commitActiveText()
            isDrawing = true
            activePoints = [toPixel(loc)]

        case .arrow, .line, .rectangle, .ellipse:
            commitActiveText()
            isDrawing = true
            shapeOrigin = normalize(loc)
            shapeEndpoint = normalize(loc)
            activePoints = []

        case .text:
            placeTextField(at: loc)
            return
        }

        needsDisplay = true
    }

    func handleMouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)

        switch currentTool {
        case .eraser:
            eraseAt(loc)

        case .pen, .highlighter:
            guard isDrawing else { return }
            activePoints.append(toPixel(loc))
            store.setActiveStroke(AnnotationStroke(
                tool: currentTool,
                color: currentColor,
                lineWidth: currentLineWidth,
                points: activePoints
            ))

        case .arrow, .line, .rectangle, .ellipse:
            guard isDrawing else { return }
            shapeEndpoint = normalize(loc)
            if let origin = shapeOrigin {
                store.setActiveStroke(AnnotationStroke(
                    tool: currentTool,
                    color: currentColor,
                    lineWidth: currentLineWidth,
                    origin: origin,
                    endpoint: normalize(loc)
                ))
            }

        case .text:
            break
        }

        needsDisplay = true
    }

    func handleMouseUp(with event: NSEvent) {
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

        case .text:
            break
        }

        needsDisplay = true
    }

    func eraseAt(_ loc: NSPoint) {
        let norm = normalize(loc)
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

    func resetShapeState() {
        shapeOrigin = nil
        shapeEndpoint = nil
        activePoints = []
    }
}
