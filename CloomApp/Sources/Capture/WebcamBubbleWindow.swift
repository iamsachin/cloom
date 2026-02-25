import AppKit
import CoreImage
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "WebcamBubble")

@MainActor
final class WebcamBubbleWindow {
    /// Fires whenever the bubble moves or resizes. Reports normalized center (0-1) and diameter in points.
    var onLayoutChanged: ((_ layout: BubbleLayout) -> Void)?

    /// Expose the panel for child window attachment (e.g. BubbleControlPill)
    var windowPanel: NSPanel? { panel }

    var panel: NSPanel?
    var imageLayer: CALayer?
    var themeLayer: CAGradientLayer?
    let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    var moveObserver: NSObjectProtocol?
    private var themeObserver: NSObjectProtocol?
    private var shapeObserver: NSObjectProtocol?

    enum BubbleSize: Int, CaseIterable {
        case small = 120
        case medium = 180
        case large = 240

        var next: BubbleSize {
            let all = BubbleSize.allCases
            guard let idx = all.firstIndex(of: self) else { return .medium }
            return all[(idx + 1) % all.count]
        }
    }

    var currentSize: BubbleSize = .medium
    var currentShape: WebcamShape = {
        let raw = UserDefaults.standard.string(forKey: "webcamShape") ?? "circle"
        return WebcamShape(rawValue: raw) ?? .circle
    }()
    var currentTheme: BubbleTheme = {
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
        let borderInset: CGFloat = currentTheme != .none ? 16 : 0
        return BubbleLayout(
            normalizedX: centerX / screenFrame.width,
            normalizedY: centerY / screenFrame.height,
            diameterPoints: frame.height - borderInset * 2,
            shape: currentShape,
            theme: currentTheme
        )
    }

    func reportLayout() {
        let layout = currentLayout()
        onLayoutChanged?(layout)
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
