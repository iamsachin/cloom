import CoreImage
import CoreGraphics
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "AnnotationRenderer")
private let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

/// Renders annotation overlays as CIImage for video burn-in.
/// Called from SCStreamOutput queue — must be thread-safe.
final class AnnotationRenderer: @unchecked Sendable {
    let ciContext: CIContext = SharedCIContext.instance
    private let store: AnnotationStore

    // Stroke cache — avoids CGContext creation every frame when strokes haven't changed.
    private var cachedStrokeImage: CIImage?
    private var cachedStrokeCount: Int = -1
    private var cachedStrokeWidth: Int = 0
    private var cachedStrokeHeight: Int = 0

    init(store: AnnotationStore) {
        self.store = store
    }

    /// Returns a CIImage overlay to composite over the screen frame, or nil if nothing to render.
    func render(screenWidth: Int, screenHeight: Int, currentTime: TimeInterval) -> CIImage? {
        // Prune expired ripples
        store.pruneExpiredRipples(currentTime: currentTime)

        let snap = store.snapshot()

        let hasStrokes = !snap.strokes.isEmpty
        let hasRipples = !snap.ripples.isEmpty
        let hasSpotlight = snap.spotlight.isEnabled

        guard hasStrokes || hasRipples || hasSpotlight else {
            cachedStrokeImage = nil
            cachedStrokeCount = -1
            return nil
        }

        let w = CGFloat(screenWidth)
        let h = CGFloat(screenHeight)
        var overlay: CIImage?

        // 1. Render strokes (cached when stable, bypassed during active drawing)
        if hasStrokes {
            let strokeCount = snap.strokes.count
            if snap.hasActiveStroke {
                // Active stroke changes every frame — skip cache
                overlay = renderStrokes(snap.strokes, width: screenWidth, height: screenHeight)
                cachedStrokeImage = nil
                cachedStrokeCount = -1
            } else if strokeCount != cachedStrokeCount || screenWidth != cachedStrokeWidth || screenHeight != cachedStrokeHeight {
                cachedStrokeImage = renderStrokes(snap.strokes, width: screenWidth, height: screenHeight)
                cachedStrokeCount = strokeCount
                cachedStrokeWidth = screenWidth
                cachedStrokeHeight = screenHeight
                overlay = cachedStrokeImage
            } else {
                overlay = cachedStrokeImage
            }
        }

        // 2. Render ripples (CIFilter-based — cheap, no caching needed)
        if hasRipples {
            for ripple in snap.ripples {
                if let rippleImage = renderRipple(ripple, width: w, height: h, currentTime: currentTime) {
                    overlay = overlay.map { rippleImage.composited(over: $0) } ?? rippleImage
                }
            }
        }

        // 3. Render spotlight (CIFilter-based — cheap, no caching needed)
        if hasSpotlight {
            if let spotlightImage = renderSpotlight(snap.spotlight, width: w, height: h) {
                overlay = overlay.map { $0.composited(over: spotlightImage) } ?? spotlightImage
            }
        }

        return overlay
    }

    // MARK: - Stroke Rendering

    private func renderStrokes(_ strokes: [AnnotationStroke], width: Int, height: Int) -> CIImage? {
        let colorSpace = sRGBColorSpace
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            logger.error("Failed to create CGContext for stroke rendering")
            return nil
        }

        // CIImage has origin at bottom-left, same as CGContext — no flip needed
        context.setLineCap(.round)
        context.setLineJoin(.round)

        for stroke in strokes {
            context.setStrokeColor(stroke.color.cgColor)
            // Scale lineWidth for Retina (points → pixels, assume 2x)
            let pixelWidth = stroke.lineWidth * 2.0

            switch stroke.tool {
            case .pen:
                context.setLineWidth(pixelWidth)
                context.setBlendMode(.normal)
                drawFreehandPath(context: context, points: stroke.points)

            case .highlighter:
                context.setLineWidth(pixelWidth * 3)
                // Use a semi-transparent version for highlighter
                let hlColor = CGColor(srgbRed: stroke.color.r, green: stroke.color.g, blue: stroke.color.b, alpha: 0.35)
                context.setStrokeColor(hlColor)
                context.setBlendMode(.normal)
                drawFreehandPath(context: context, points: stroke.points)

            case .arrow:
                context.setLineWidth(pixelWidth)
                context.setBlendMode(.normal)
                if let origin = stroke.origin, let endpoint = stroke.endpoint {
                    drawArrow(context: context, from: origin, to: endpoint, lineWidth: pixelWidth)
                }

            case .line:
                context.setLineWidth(pixelWidth)
                context.setBlendMode(.normal)
                if let origin = stroke.origin, let endpoint = stroke.endpoint {
                    context.beginPath()
                    context.move(to: scalePoint(origin, width: width, height: height))
                    context.addLine(to: scalePoint(endpoint, width: width, height: height))
                    context.strokePath()
                }

            case .rectangle:
                context.setLineWidth(pixelWidth)
                context.setBlendMode(.normal)
                if let origin = stroke.origin, let endpoint = stroke.endpoint {
                    let p1 = scalePoint(origin, width: width, height: height)
                    let p2 = scalePoint(endpoint, width: width, height: height)
                    let rect = CGRect(
                        x: min(p1.x, p2.x), y: min(p1.y, p2.y),
                        width: abs(p2.x - p1.x), height: abs(p2.y - p1.y)
                    )
                    context.stroke(rect)
                }

            case .ellipse:
                context.setLineWidth(pixelWidth)
                context.setBlendMode(.normal)
                if let origin = stroke.origin, let endpoint = stroke.endpoint {
                    let p1 = scalePoint(origin, width: width, height: height)
                    let p2 = scalePoint(endpoint, width: width, height: height)
                    let rect = CGRect(
                        x: min(p1.x, p2.x), y: min(p1.y, p2.y),
                        width: abs(p2.x - p1.x), height: abs(p2.y - p1.y)
                    )
                    context.strokeEllipse(in: rect)
                }

            case .eraser:
                break // Eraser removes strokes, doesn't draw
            }
        }

        guard let cgImage = context.makeImage() else { return nil }
        return CIImage(cgImage: cgImage)
    }

    private func drawFreehandPath(context: CGContext, points: [StrokePoint]) {
        guard points.count >= 2 else { return }
        context.beginPath()
        context.move(to: points[0].cgPoint)
        for i in 1..<points.count {
            context.addLine(to: points[i].cgPoint)
        }
        context.strokePath()
    }

    private func drawArrow(context: CGContext, from origin: CGPoint, to endpoint: CGPoint, lineWidth: CGFloat) {
        let p1 = scalePoint(origin, width: Int(context.width), height: Int(context.height))
        let p2 = scalePoint(endpoint, width: Int(context.width), height: Int(context.height))

        // Draw line
        context.beginPath()
        context.move(to: p1)
        context.addLine(to: p2)
        context.strokePath()

        // Draw arrowhead
        let angle = atan2(p2.y - p1.y, p2.x - p1.x)
        let arrowLength = max(lineWidth * 4, 16)
        let arrowAngle: CGFloat = .pi / 6

        let tip1 = CGPoint(
            x: p2.x - arrowLength * cos(angle - arrowAngle),
            y: p2.y - arrowLength * sin(angle - arrowAngle)
        )
        let tip2 = CGPoint(
            x: p2.x - arrowLength * cos(angle + arrowAngle),
            y: p2.y - arrowLength * sin(angle + arrowAngle)
        )

        context.beginPath()
        context.move(to: p2)
        context.addLine(to: tip1)
        context.move(to: p2)
        context.addLine(to: tip2)
        context.strokePath()
    }

    /// Convert normalized (0-1) point to pixel coordinates.
    private func scalePoint(_ point: CGPoint, width: Int, height: Int) -> CGPoint {
        CGPoint(x: point.x * CGFloat(width), y: point.y * CGFloat(height))
    }

    // MARK: - Ripple Rendering

    private func renderRipple(_ ripple: ClickRipple, width: CGFloat, height: CGFloat, currentTime: TimeInterval) -> CIImage? {
        let elapsed = currentTime - ripple.startTime
        guard elapsed >= 0 && elapsed <= ripple.duration else { return nil }

        let progress = CGFloat(elapsed / ripple.duration)
        let currentRadius = ripple.maxRadius * 2.0 * progress // Scale for Retina
        let alpha = (1.0 - progress) * ripple.color.a

        let centerX = ripple.normalizedX * width
        let centerY = ripple.normalizedY * height

        // Create a ring using two radial gradients
        let innerRadius = max(0, currentRadius - 4)
        guard let filter = CIFilter(name: "CIRadialGradient") else { return nil }
        let ringColor = CIColor(red: ripple.color.r, green: ripple.color.g, blue: ripple.color.b, alpha: alpha)
        filter.setValue(CIVector(x: centerX, y: centerY), forKey: "inputCenter")
        filter.setValue(innerRadius, forKey: "inputRadius0")
        filter.setValue(currentRadius, forKey: "inputRadius1")
        filter.setValue(ringColor, forKey: "inputColor0")
        filter.setValue(CIColor.clear, forKey: "inputColor1")

        return filter.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }

    // MARK: - Spotlight Rendering

    private func renderSpotlight(_ spotlight: SpotlightState, width: CGFloat, height: CGFloat) -> CIImage? {
        let centerX = spotlight.normalizedX * width
        let centerY = spotlight.normalizedY * height
        let radius = spotlight.radius * 2.0 // Retina scale

        // Radial gradient: clear at center → dark at edges
        guard let filter = CIFilter(name: "CIRadialGradient") else { return nil }
        filter.setValue(CIVector(x: centerX, y: centerY), forKey: "inputCenter")
        filter.setValue(radius, forKey: "inputRadius0")
        filter.setValue(radius * 3, forKey: "inputRadius1")
        filter.setValue(CIColor.clear, forKey: "inputColor0")
        filter.setValue(CIColor(red: 0, green: 0, blue: 0, alpha: spotlight.dimOpacity), forKey: "inputColor1")

        return filter.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }
}
