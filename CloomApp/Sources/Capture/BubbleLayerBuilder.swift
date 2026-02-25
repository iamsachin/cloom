import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "WebcamBubble")

// MARK: - Panel Creation & Emoji Frame

extension WebcamBubbleWindow {

    func createPanel(centeredAt center: NSPoint? = nil) {
        let diameter = CGFloat(currentSize.rawValue)
        let width = diameter * currentShape.aspectRatio
        let height = diameter
        let cornerRadius = currentShape.cornerRadius(forHeight: height)

        // Expand panel to include emoji frame padding
        let framePad: CGFloat = currentDecoration != .none
            ? EmojiFrameRenderer.framePadding(for: min(width, height))
            : 0
        let panelWidth = width + framePad * 2
        let panelHeight = height + framePad * 2

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

        let innerRect = NSRect(x: framePad, y: framePad, width: width, height: height)

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

        // Emoji frame stickers (above the video clip layer)
        if currentDecoration != .none {
            let emojiContainer = CALayer()
            emojiContainer.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
            emojiContainer.masksToBounds = false

            let stickers = EmojiFrameRenderer.positionStickers(
                frame: currentDecoration,
                bubbleWidth: width,
                bubbleHeight: height
            )

            for sticker in stickers {
                let textLayer = CATextLayer()
                textLayer.string = sticker.emoji
                textLayer.fontSize = sticker.fontSize
                textLayer.alignmentMode = .center
                textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0

                // Flip Y: positionStickers uses math convention (Y-up) but
                // CALayer Y-up means visually "top of screen". Flip to match SwiftUI preview.
                let flippedY = panelHeight - sticker.y
                let layerSize = sticker.fontSize * 1.3
                textLayer.frame = CGRect(
                    x: sticker.x - layerSize / 2,
                    y: flippedY - layerSize / 2,
                    width: layerSize,
                    height: layerSize
                )

                if sticker.rotationDegrees != 0 {
                    textLayer.transform = CATransform3DMakeRotation(
                        sticker.rotationDegrees * .pi / 180.0, 0, 0, 1
                    )
                }

                emojiContainer.addSublayer(textLayer)
            }

            rootLayer.addSublayer(emojiContainer)
            self.emojiFrameLayer = emojiContainer
        }

        panel.contentView = contentView
        self.panel = panel
        self.imageLayer = imgLayer

        // Observe window move to update compositor layout (throttled to ~15Hz)
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let now = CACurrentMediaTime()
            if now - self.lastLayoutReport > 0.066 {
                self.lastLayoutReport = now
                Task { @MainActor in
                    self.reportLayout()
                }
            }
        }

        logger.info("Webcam bubble panel created (\(width)x\(height) \(self.currentShape.rawValue))")

        // Report initial layout
        reportLayout()
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
        self.emojiFrameLayer = nil

        createPanel(centeredAt: center)
        self.panel?.orderFrontRegardless()

        reportLayout()
    }
}
