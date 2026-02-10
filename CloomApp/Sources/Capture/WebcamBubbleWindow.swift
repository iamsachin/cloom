import AppKit
import CoreImage
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "WebcamBubble")

@MainActor
final class WebcamBubbleWindow {
    private var panel: NSPanel?
    private var imageLayer: CALayer?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var scrollMonitor: Any?

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

    func show() {
        if panel == nil {
            createPanel()
        }
        panel?.orderFrontRegardless()
        logger.info("Webcam bubble shown")
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        imageLayer = nil
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        logger.info("Webcam bubble dismissed")
    }

    func updateFrame(_ ciImage: CIImage) {
        guard let imageLayer else {
            logger.warning("updateFrame called but imageLayer is nil")
            return
        }
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
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
        let diameter = CGFloat(currentSize.rawValue)
        guard let panel else { return }

        let oldFrame = panel.frame
        let centerX = oldFrame.midX
        let centerY = oldFrame.midY

        let newFrame = NSRect(
            x: centerX - diameter / 2,
            y: centerY - diameter / 2,
            width: diameter,
            height: diameter
        )
        panel.setFrame(newFrame, display: true, animate: true)

        // Update layer geometry
        if let contentView = panel.contentView {
            contentView.layer?.cornerRadius = diameter / 2
            imageLayer?.frame = contentView.bounds
        }
    }

    // MARK: - Panel creation

    private func createPanel() {
        let diameter = CGFloat(currentSize.rawValue)

        let margin: CGFloat = 20
        let origin = NSPoint(x: margin, y: margin)

        let panel = NSPanel(
            contentRect: NSRect(x: origin.x, y: origin.y, width: diameter, height: diameter),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = .none

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
        contentView.wantsLayer = true
        guard let rootLayer = contentView.layer else {
            logger.error("Failed to create layer for webcam bubble")
            return
        }
        rootLayer.cornerRadius = diameter / 2
        rootLayer.masksToBounds = true
        rootLayer.borderWidth = 3
        rootLayer.borderColor = NSColor.white.withAlphaComponent(0.8).cgColor
        rootLayer.backgroundColor = NSColor.black.cgColor

        let imgLayer = CALayer()
        imgLayer.frame = contentView.bounds
        imgLayer.contentsGravity = .resizeAspectFill
        rootLayer.addSublayer(imgLayer)

        let borderLayer = CALayer()
        borderLayer.frame = contentView.bounds
        borderLayer.cornerRadius = diameter / 2
        borderLayer.borderWidth = 3
        borderLayer.borderColor = NSColor.white.withAlphaComponent(0.8).cgColor
        rootLayer.addSublayer(borderLayer)

        panel.contentView = contentView
        self.panel = panel
        self.imageLayer = imgLayer

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, let panel = self.panel else { return event }
            if let window = event.window, window === panel {
                self.cycleSize()
                return nil
            }
            let globalPoint = NSEvent.mouseLocation
            if panel.frame.contains(globalPoint) {
                self.cycleSize()
                return nil
            }
            return event
        }

        logger.info("Webcam bubble panel created (\(diameter)px)")
    }
}
