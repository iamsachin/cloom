import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "WebcamBubble")

// MARK: - Panel Creation & Theme

extension WebcamBubbleWindow {

    func createPanel(centeredAt center: NSPoint? = nil) {
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

    func applyTheme() {
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

    func rebuildPanel() {
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
}
