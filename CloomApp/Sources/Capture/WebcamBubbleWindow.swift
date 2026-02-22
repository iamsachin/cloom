import AppKit
import CoreImage
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "WebcamBubble")

/// Custom NSView that forwards clicks to a handler, distinguishing clicks from drags.
private class BubbleContentView: NSView {
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

@MainActor
final class WebcamBubbleWindow {
    /// Fires whenever the bubble moves or resizes. Reports normalized center (0-1) and diameter in points.
    var onLayoutChanged: ((_ layout: BubbleLayout) -> Void)?

    /// Expose the panel for child window attachment (e.g. BubbleControlPill)
    var windowPanel: NSPanel? { panel }

    private var panel: NSPanel?
    private var imageLayer: CALayer?
    private var themeLayer: CAGradientLayer?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var moveObserver: NSObjectProtocol?
    private var themeObserver: NSObjectProtocol?
    private var shapeObserver: NSObjectProtocol?

    private enum BubbleSize: Int, CaseIterable {
        case small = 120
        case medium = 180
        case large = 240

        var next: BubbleSize {
            let all = BubbleSize.allCases
            guard let idx = all.firstIndex(of: self) else { return .medium }
            return all[(idx + 1) % all.count]
        }
    }

    private var currentSize: BubbleSize = .medium
    private var currentShape: WebcamShape = {
        let raw = UserDefaults.standard.string(forKey: "webcamShape") ?? "circle"
        return WebcamShape(rawValue: raw) ?? .circle
    }()
    private var currentTheme: BubbleTheme = {
        let raw = UserDefaults.standard.string(forKey: "webcamBubbleTheme") ?? "none"
        return BubbleTheme(rawValue: raw) ?? .none
    }()

    func show() {
        if panel == nil {
            createPanel()
        }
        panel?.orderFrontRegardless()
        startObservingDefaults()
        logger.info("Webcam bubble shown")
    }

    func dismiss() {
        if let obs = moveObserver {
            NotificationCenter.default.removeObserver(obs)
            moveObserver = nil
        }
        stopObservingDefaults()
        panel?.orderOut(nil)
        panel = nil
        imageLayer = nil
        themeLayer = nil
        onLayoutChanged = nil
        logger.info("Webcam bubble dismissed")
    }

    func updateFrame(_ ciImage: CIImage) {
        guard let imageLayer else {
            logger.warning("updateFrame called but imageLayer is nil")
            return
        }
        // Flip horizontally to unmirror the front camera
        let flipped = ciImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1)
            .translatedBy(x: -ciImage.extent.width, y: 0))
        guard let cgImage = ciContext.createCGImage(flipped, from: flipped.extent) else {
            logger.warning("Failed to create CGImage from CIImage")
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.contents = cgImage
        CATransaction.commit()
    }

    func cycleSize() {
        currentSize = currentSize.next
        rebuildPanel()
    }

    func cycleShape() {
        currentShape = currentShape.next
        UserDefaults.standard.set(currentShape.rawValue, forKey: "webcamShape")
        rebuildPanel()
    }

    func updateShape(_ shape: WebcamShape) {
        guard shape != currentShape else { return }
        currentShape = shape
        rebuildPanel()
    }

    func updateTheme(_ theme: BubbleTheme) {
        guard theme != currentTheme else { return }
        let hadBorder = currentTheme != .none
        let willHaveBorder = theme != .none
        currentTheme = theme
        if hadBorder != willHaveBorder {
            // Panel size changes — full rebuild needed
            rebuildPanel()
        } else {
            applyTheme()
            reportLayout()
        }
    }

    /// Returns the current bubble layout as normalized coordinates relative to the main screen.
    func currentLayout() -> BubbleLayout {
        guard let panel, let screen = panel.screen ?? NSScreen.main else {
            return .default
        }
        let frame = panel.frame
        let screenFrame = screen.frame
        let centerX = frame.midX - screenFrame.origin.x
        let centerY = frame.midY - screenFrame.origin.y
        let borderInset: CGFloat = currentTheme != .none ? 16 : 0  // 6 border + 10 glow padding
        return BubbleLayout(
            normalizedX: centerX / screenFrame.width,
            normalizedY: centerY / screenFrame.height,
            diameterPoints: frame.height - borderInset * 2,
            shape: currentShape,
            theme: currentTheme
        )
    }

    private func reportLayout() {
        let layout = currentLayout()
        onLayoutChanged?(layout)
    }

    private func rebuildPanel() {
        guard let panel else { return }

        // Remember current center position
        let oldFrame = panel.frame
        let center = NSPoint(x: oldFrame.midX, y: oldFrame.midY)

        if let obs = moveObserver {
            NotificationCenter.default.removeObserver(obs)
            moveObserver = nil
        }
        panel.orderOut(nil)
        self.panel = nil
        self.imageLayer = nil
        self.themeLayer = nil

        createPanel(centeredAt: center)
        self.panel?.orderFrontRegardless()

        reportLayout()
    }

    // MARK: - Panel creation

    private func createPanel(centeredAt center: NSPoint? = nil) {
        let diameter = CGFloat(currentSize.rawValue)
        let width = diameter * currentShape.aspectRatio
        let height = diameter
        let cornerRadius = currentShape.cornerRadius(forHeight: height)

        // Expand panel to include theme border + outer glow so nothing is clipped
        let themeBorderWidth: CGFloat = currentTheme != .none ? 6 : 0
        let glowPadding: CGFloat = currentTheme != .none ? 10 : 0
        let totalInset = themeBorderWidth + glowPadding
        let panelWidth = width + totalInset * 2
        let panelHeight = height + totalInset * 2

        let origin: NSPoint
        if let center {
            origin = NSPoint(x: center.x - panelWidth / 2, y: center.y - panelHeight / 2)
        } else {
            let margin: CGFloat = 20
            origin = NSPoint(x: margin, y: margin)
        }

        let panel = NSPanel(
            contentRect: NSRect(x: origin.x, y: origin.y, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = .none

        let contentView = BubbleContentView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        contentView.onClick = { [weak self] in
            self?.cycleSize()
        }
        contentView.onRightClick = { [weak self] in
            self?.cycleShape()
        }
        contentView.wantsLayer = true
        guard let rootLayer = contentView.layer else {
            logger.error("Failed to create layer for webcam bubble")
            return
        }
        rootLayer.masksToBounds = false
        rootLayer.backgroundColor = NSColor.clear.cgColor

        // Inner rect for the video content (inset by border + glow padding)
        let innerRect = NSRect(x: totalInset, y: totalInset, width: width, height: height)
        // Theme border rect (inset only by glow padding)
        let borderRect = NSRect(
            x: glowPadding, y: glowPadding,
            width: width + themeBorderWidth * 2,
            height: height + themeBorderWidth * 2
        )
        let borderCornerRadius = currentShape.cornerRadius(forHeight: borderRect.height)

        // Shadow layer — soft drop shadow
        let shadowLayer = CALayer()
        shadowLayer.frame = innerRect
        shadowLayer.cornerRadius = cornerRadius
        shadowLayer.backgroundColor = NSColor.black.cgColor
        shadowLayer.shadowColor = NSColor.black.cgColor
        shadowLayer.shadowOpacity = 0.35
        shadowLayer.shadowRadius = 10
        shadowLayer.shadowOffset = CGSize(width: 0, height: -3)
        rootLayer.addSublayer(shadowLayer)

        // Theme border ring with subtle colored glow
        let themeBorder = CAGradientLayer()
        themeBorder.frame = borderRect
        themeBorder.cornerRadius = borderCornerRadius
        themeBorder.isHidden = currentTheme == .none
        themeBorder.masksToBounds = false
        rootLayer.addSublayer(themeBorder)
        self.themeLayer = themeBorder

        // Bright inner edge between border and video for depth
        if currentTheme != .none {
            let innerGlow = CALayer()
            innerGlow.frame = NSRect(
                x: totalInset - 1, y: totalInset - 1,
                width: width + 2, height: height + 2
            )
            innerGlow.cornerRadius = cornerRadius + 1
            innerGlow.borderWidth = 1.5
            innerGlow.borderColor = NSColor.white.withAlphaComponent(0.5).cgColor
            rootLayer.addSublayer(innerGlow)
        }

        // Clipping container for the video feed
        let clipLayer = CALayer()
        clipLayer.frame = innerRect
        clipLayer.cornerRadius = cornerRadius
        clipLayer.masksToBounds = true
        clipLayer.backgroundColor = NSColor.darkGray.cgColor
        rootLayer.addSublayer(clipLayer)

        // Video image layer
        let imgLayer = CALayer()
        imgLayer.frame = NSRect(x: 0, y: 0, width: width, height: height)
        imgLayer.contentsGravity = .resizeAspectFill
        clipLayer.addSublayer(imgLayer)

        // Subtle inner border — thin ring for definition
        let borderLayer = CALayer()
        borderLayer.frame = NSRect(x: 0, y: 0, width: width, height: height)
        borderLayer.cornerRadius = cornerRadius
        borderLayer.borderWidth = 1
        borderLayer.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        clipLayer.addSublayer(borderLayer)

        panel.contentView = contentView
        self.panel = panel
        self.imageLayer = imgLayer

        applyTheme()

        // Observe window move to update compositor layout
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reportLayout()
            }
        }

        logger.info("Webcam bubble panel created (\(width)x\(height) \(self.currentShape.rawValue))")

        // Report initial layout
        reportLayout()
    }

    // MARK: - Theme

    private func applyTheme() {
        guard let themeLayer else { return }

        if currentTheme == .none {
            themeLayer.isHidden = true
            return
        }

        themeLayer.isHidden = false
        let diameter = CGFloat(currentSize.rawValue)
        let width = diameter * currentShape.aspectRatio
        let height = diameter
        let themeBorderWidth: CGFloat = 6
        let glowPadding: CGFloat = 10
        let borderRect = NSRect(
            x: glowPadding, y: glowPadding,
            width: width + themeBorderWidth * 2,
            height: height + themeBorderWidth * 2
        )
        themeLayer.frame = borderRect
        themeLayer.cornerRadius = currentShape.cornerRadius(forHeight: borderRect.height)

        // Determine the primary glow color for the shadow
        let glowColor: CGColor
        if let gradientColors = currentTheme.gradientNSColors() {
            themeLayer.colors = [gradientColors.0.cgColor, gradientColors.1.cgColor]
            themeLayer.startPoint = CGPoint(x: 0, y: 1)
            themeLayer.endPoint = CGPoint(x: 1, y: 0)
            themeLayer.backgroundColor = nil
            // Blend glow from the first gradient color
            glowColor = gradientColors.0.cgColor
        } else if let solidColor = currentTheme.cgColor() {
            themeLayer.colors = nil
            themeLayer.backgroundColor = solidColor
            glowColor = solidColor
        } else {
            glowColor = NSColor.clear.cgColor
        }

        // Subtle colored outer glow
        themeLayer.shadowColor = glowColor
        themeLayer.shadowOpacity = 0.45
        themeLayer.shadowRadius = 8
        themeLayer.shadowOffset = .zero
    }

    // MARK: - UserDefaults Observers

    private func startObservingDefaults() {
        stopObservingDefaults()

        themeObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let newThemeRaw = UserDefaults.standard.string(forKey: "webcamBubbleTheme") ?? "none"
                let newTheme = BubbleTheme(rawValue: newThemeRaw) ?? .none
                if newTheme != self.currentTheme {
                    self.updateTheme(newTheme)
                }
                let newShapeRaw = UserDefaults.standard.string(forKey: "webcamShape") ?? "circle"
                let newShape = WebcamShape(rawValue: newShapeRaw) ?? .circle
                if newShape != self.currentShape {
                    self.updateShape(newShape)
                }
            }
        }
    }

    private func stopObservingDefaults() {
        if let obs = themeObserver {
            NotificationCenter.default.removeObserver(obs)
            themeObserver = nil
        }
        if let obs = shapeObserver {
            NotificationCenter.default.removeObserver(obs)
            shapeObserver = nil
        }
    }
}
