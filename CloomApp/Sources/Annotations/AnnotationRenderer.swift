import CoreImage
import CoreGraphics
import CoreText
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "AnnotationRenderer")
private let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

/// Renders annotation overlays as CIImage for video burn-in.
/// Called from SCStreamOutput queue — must be thread-safe.
final class AnnotationRenderer: @unchecked Sendable {
    private let ciContext: CIContext = SharedCIContext.instance
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
        let hasKeystrokes = snap.keystroke.isEnabled && !snap.keystroke.events.isEmpty

        guard hasStrokes || hasRipples || hasSpotlight || hasKeystrokes else {
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

        // 4. Render keystrokes
        if hasKeystrokes {
            store.pruneExpiredKeystrokes(currentTime: currentTime)
            if let keystrokeImage = renderKeystrokes(snap.keystroke, width: screenWidth, height: screenHeight, currentTime: currentTime) {
                overlay = overlay.map { keystrokeImage.composited(over: $0) } ?? keystrokeImage
            }
        }

        return overlay
    }

    /// Renders the composited CIImage into the given pixel buffer using the internal CIContext.
    func renderToBuffer(_ image: CIImage, to buffer: CVPixelBuffer, bounds: CGRect) {
        ciContext.render(image, to: buffer, bounds: bounds, colorSpace: sRGBColorSpace)
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

            case .text:
                if let text = stroke.text, let origin = stroke.origin {
                    let pos = scalePoint(origin, width: width, height: height)
                    let fontSize = (stroke.fontSize ?? 24.0) * 2.0 // Retina
                    let font = CTFontCreateWithName("SFPro-Medium" as CFString, fontSize, nil)
                    let attrs: [CFString: Any] = [
                        kCTFontAttributeName: font,
                        kCTForegroundColorAttributeName: stroke.color.cgColor
                    ]
                    let attrString = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
                    let ctLine = CTLineCreateWithAttributedString(attrString)
                    context.saveGState()
                    context.textPosition = CGPoint(x: pos.x, y: pos.y - fontSize * 0.3)
                    CTLineDraw(ctLine, context)
                    context.restoreGState()
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

    // MARK: - Zoom

    func applyZoom(to baseImage: CIImage, screenWidth: Int, screenHeight: Int, currentTime: TimeInterval) -> CIImage? {
        let snap = store.snapshot()
        let zoom = snap.zoom

        // Handle both zoom-in (isActive) and zoom-out (isAnimatingOut) states
        guard zoom.isActive || zoom.isAnimatingOut else { return nil }

        let elapsed = currentTime - zoom.startTime
        let rawProgress = min(1.0, elapsed / zoom.animationDuration)
        // Ease-in-out curve
        let easedProgress = rawProgress < 0.5
            ? 2.0 * rawProgress * rawProgress
            : 1.0 - pow(-2.0 * rawProgress + 2.0, 2) / 2.0

        let progress: CGFloat
        if zoom.isActive {
            // Zooming in: 0 → 1
            progress = easedProgress
        } else {
            // Zooming out: 1 → 0
            progress = 1.0 - easedProgress
            if rawProgress >= 1.0 {
                // Animation complete — clear the animating-out state
                store.clearZoomAnimation()
                return nil
            }
        }

        let currentZoom = 1.0 + (zoom.zoomLevel - 1.0) * progress
        guard currentZoom > 1.001 else { return nil }

        let w = CGFloat(screenWidth)
        let h = CGFloat(screenHeight)
        let centerX = zoom.normalizedCenterX * w
        let centerY = zoom.normalizedCenterY * h

        // Crop region size (inverse of zoom level)
        let cropW = w / currentZoom
        let cropH = h / currentZoom

        // Clamp crop rect to image bounds
        let cropX = min(max(centerX - cropW / 2, 0), w - cropW)
        let cropY = min(max(centerY - cropH / 2, 0), h - cropH)
        let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)

        // Crop and scale back to full resolution
        let cropped = baseImage.cropped(to: cropRect)
        let scaleX = w / cropW
        let scaleY = h / cropH
        let scaled = cropped
            .transformed(by: CGAffineTransform(translationX: -cropX, y: -cropY))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        return scaled
    }

    // MARK: - Keystroke Rendering

    private func renderKeystrokes(_ keystroke: KeystrokeState, width: Int, height: Int, currentTime: TimeInterval) -> CIImage? {
        let events = keystroke.events.filter { $0.opacity(at: currentTime) > 0 }
        guard !events.isEmpty else { return nil }

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
            return nil
        }

        let scale: CGFloat = 2.0 // Retina
        let fontSize: CGFloat = 18.0 * scale
        let paddingH: CGFloat = 14.0 * scale
        let paddingV: CGFloat = 8.0 * scale
        let cornerRadius: CGFloat = 10.0 * scale
        let spacing: CGFloat = 6.0 * scale
        let edgePadding: CGFloat = 40.0 * scale

        let font = CTFontCreateWithName("SFPro-Medium" as CFString, fontSize, nil)

        // Measure all pills first
        var pills: [(label: String, opacity: CGFloat, size: CGSize)] = []
        for event in events {
            let opacity = event.opacity(at: currentTime)
            let attrs: [CFString: Any] = [kCTFontAttributeName: font]
            let attrStr = CFAttributedStringCreate(nil, event.label as CFString, attrs as CFDictionary)!
            let line = CTLineCreateWithAttributedString(attrStr)
            let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
            let pillW = textBounds.width + paddingH * 2
            let pillH = fontSize + paddingV * 2
            pills.append((event.label, opacity, CGSize(width: pillW, height: pillH)))
        }

        // Stack pills from the position corner
        let isBottom = keystroke.position == .bottomLeft || keystroke.position == .bottomRight
        let isLeft = keystroke.position == .bottomLeft || keystroke.position == .topLeft

        let totalHeight = pills.reduce(0) { $0 + $1.size.height } + CGFloat(max(0, pills.count - 1)) * spacing
        var y: CGFloat = isBottom ? edgePadding : (CGFloat(height) - edgePadding - totalHeight)

        for pill in pills {
            let x: CGFloat = isLeft ? edgePadding : (CGFloat(width) - edgePadding - pill.size.width)
            let pillRect = CGRect(x: x, y: y, width: pill.size.width, height: pill.size.height)

            // Background pill
            context.saveGState()
            context.setAlpha(pill.opacity * 0.7)
            let path = CGPath(roundedRect: pillRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.addPath(path)
            context.fillPath()
            context.restoreGState()

            // Text
            context.saveGState()
            context.setAlpha(pill.opacity)
            let textAttrs: [CFString: Any] = [
                kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
            ]
            let textStr = CFAttributedStringCreate(nil, pill.label as CFString, textAttrs as CFDictionary)!
            let ctLine = CTLineCreateWithAttributedString(textStr)
            let textBounds = CTLineGetBoundsWithOptions(ctLine, .useOpticalBounds)
            let textX = pillRect.midX - textBounds.width / 2
            let textY = pillRect.midY - fontSize * 0.35
            context.textPosition = CGPoint(x: textX, y: textY)
            CTLineDraw(ctLine, context)
            context.restoreGState()

            y += pill.size.height + spacing
        }

        guard let cgImage = context.makeImage() else { return nil }
        return CIImage(cgImage: cgImage)
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
