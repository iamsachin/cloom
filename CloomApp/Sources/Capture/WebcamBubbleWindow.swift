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

    private enum BubbleSize: Int, CaseIterable {
        case small = 120
        case medium = 180
        case large = 240

        var next: BubbleSize {
            let all = BubbleSize.allCases
            let idx = all.firstIndex(of: self)!
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
        logger.info("Webcam bubble shown")
    }

    func dismiss() {
        if let obs = moveObserver {
            NotificationCenter.default.removeObserver(obs)
            moveObserver = nil
        }
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
        currentTheme = theme
        applyTheme()
        reportLayout()
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
        return BubbleLayout(
            normalizedX: centerX / screenFrame.width,
            normalizedY: centerY / screenFrame.height,
            diameterPoints: frame.height,
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

        let origin: NSPoint
        if let center {
            origin = NSPoint(x: center.x - width / 2, y: center.y - height / 2)
        } else {
            let margin: CGFloat = 20
            origin = NSPoint(x: margin, y: margin)
        }

        let panel = NSPanel(
            contentRect: NSRect(x: origin.x, y: origin.y, width: width, height: height),
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

        let contentView = BubbleContentView(frame: NSRect(x: 0, y: 0, width: width, height: height))
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

        // Shadow layer — soft drop shadow like Loom
        let shadowLayer = CALayer()
        shadowLayer.frame = contentView.bounds
        shadowLayer.cornerRadius = cornerRadius
        shadowLayer.backgroundColor = NSColor.black.cgColor
        shadowLayer.shadowColor = NSColor.black.cgColor
        shadowLayer.shadowOpacity = 0.4
        shadowLayer.shadowRadius = 12
        shadowLayer.shadowOffset = CGSize(width: 0, height: -4)
        rootLayer.addSublayer(shadowLayer)

        // Theme layer (between shadow and clip) for border ring
        let themeBorder = CAGradientLayer()
        let themeBorderWidth: CGFloat = currentTheme != .none ? 8 : 0
        themeBorder.frame = NSRect(
            x: -themeBorderWidth, y: -themeBorderWidth,
            width: width + themeBorderWidth * 2,
            height: height + themeBorderWidth * 2
        )
        themeBorder.cornerRadius = currentShape.cornerRadius(forHeight: height + themeBorderWidth * 2)
        themeBorder.isHidden = currentTheme == .none
        rootLayer.addSublayer(themeBorder)
        self.themeLayer = themeBorder

        // Clipping container for the video feed
        let clipLayer = CALayer()
        clipLayer.frame = contentView.bounds
        clipLayer.cornerRadius = cornerRadius
        clipLayer.masksToBounds = true
        clipLayer.backgroundColor = NSColor.black.cgColor
        rootLayer.addSublayer(clipLayer)

        // Video image layer
        let imgLayer = CALayer()
        imgLayer.frame = contentView.bounds
        imgLayer.contentsGravity = .resizeAspectFill
        clipLayer.addSublayer(imgLayer)

        // Subtle inner border — thin ring for definition
        let borderLayer = CALayer()
        borderLayer.frame = contentView.bounds
        borderLayer.cornerRadius = cornerRadius
        borderLayer.borderWidth = 1.5
        borderLayer.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
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
        let height = CGFloat(currentSize.rawValue)
        let width = height * currentShape.aspectRatio
        let themeBorderWidth: CGFloat = 8
        themeLayer.frame = NSRect(
            x: -themeBorderWidth, y: -themeBorderWidth,
            width: width + themeBorderWidth * 2,
            height: height + themeBorderWidth * 2
        )
        themeLayer.cornerRadius = currentShape.cornerRadius(forHeight: height + themeBorderWidth * 2)

        if let gradientColors = currentTheme.gradientNSColors() {
            themeLayer.colors = [gradientColors.0.cgColor, gradientColors.1.cgColor]
            themeLayer.startPoint = CGPoint(x: 0, y: 1)
            themeLayer.endPoint = CGPoint(x: 1, y: 0)
            themeLayer.backgroundColor = nil
        } else if let solidColor = currentTheme.cgColor() {
            themeLayer.colors = nil
            themeLayer.backgroundColor = solidColor
        }
    }
}
