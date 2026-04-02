import AppKit
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ZoomClickMonitor")

/// Monitors global mouse clicks to activate zoom.
/// While zoomed, clicks pass through to apps — a close button on the overlay dismisses zoom.
@MainActor
final class ZoomClickMonitor {
    private let store: AnnotationStore
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var captureArea: CGRect = .zero
    private var overlayWindow: ZoomOverlayWindow?
    private var isZoomed = false
    private var dismissedAt: TimeInterval = 0

    init(store: AnnotationStore) {
        self.store = store
    }

    func start(captureArea: CGRect) {
        self.captureArea = captureArea
        stopMonitors()
        startMonitors()
        logger.info("Zoom click monitor started")
    }

    func stop() {
        stopMonitors()
        dismissZoom()
        store.setZoomEnabled(false)
    }

    private func startMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleClick(event)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleClick(event)
            }
            return event
        }
    }

    private func stopMonitors() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handleClick(_ event: NSEvent) {
        // Don't activate while zoomed or during cooldown after dismiss
        guard !isZoomed else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - dismissedAt > 0.4 else { return }

        let screenLocation = NSEvent.mouseLocation
        guard captureArea.width > 0, captureArea.height > 0 else { return }

        let normalizedX = (screenLocation.x - captureArea.origin.x) / captureArea.width
        let normalizedY = (screenLocation.y - captureArea.origin.y) / captureArea.height
        guard normalizedX >= 0, normalizedX <= 1, normalizedY >= 0, normalizedY <= 1 else { return }

        activateZoom(normalizedX: normalizedX, normalizedY: normalizedY)
    }

    private func activateZoom(normalizedX: CGFloat, normalizedY: CGFloat) {
        isZoomed = true
        store.activateZoom(normalizedX: normalizedX, normalizedY: normalizedY)

        let snap = store.snapshot()
        let cropFraction = 1.0 / snap.zoom.zoomLevel
        let cropW = captureArea.width * cropFraction
        let cropH = captureArea.height * cropFraction
        let cropX = min(max(captureArea.origin.x + normalizedX * captureArea.width - cropW / 2,
                            captureArea.origin.x), captureArea.maxX - cropW)
        let cropY = min(max(captureArea.origin.y + normalizedY * captureArea.height - cropH / 2,
                            captureArea.origin.y), captureArea.maxY - cropH)
        let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)

        if overlayWindow == nil {
            overlayWindow = ZoomOverlayWindow()
        }
        overlayWindow?.show(screenFrame: captureArea, cropRect: cropRect) { [weak self] in
            self?.dismissZoom()
        }
        logger.debug("Zoom activated at (\(normalizedX), \(normalizedY))")
    }

    private func dismissZoom() {
        guard isZoomed else {
            overlayWindow?.dismiss()
            overlayWindow = nil
            return
        }
        isZoomed = false
        dismissedAt = ProcessInfo.processInfo.systemUptime
        store.deactivateZoom()
        overlayWindow?.dismiss()
        overlayWindow = nil
        logger.debug("Zoom deactivated")
    }
}

// MARK: - Zoom Overlay Window

/// Full-screen transparent overlay that dims outside the zoom crop region,
/// draws a border, and provides a close button. Uses sharingType = .none
/// so it's invisible to screen capture. Mouse events pass through except
/// the close button.
@MainActor
private final class ZoomOverlayWindow {
    private var overlayPanel: NSPanel?
    private var overlayView: ZoomOverlayView?
    private var closePanel: NSPanel?
    private var onClose: (() -> Void)?

    func show(screenFrame: CGRect, cropRect: CGRect, onClose: @escaping () -> Void) {
        self.onClose = onClose

        // Main overlay (pass-through, draws dim + border)
        if overlayPanel == nil {
            createOverlayPanel(screenFrame: screenFrame)
        }
        overlayView?.cropRect = cropRect
        overlayView?.screenFrame = screenFrame
        overlayView?.needsDisplay = true
        overlayPanel?.orderFrontRegardless()

        // Close button (clickable, small panel at top-right of crop rect)
        showCloseButton(cropRect: cropRect, screenFrame: screenFrame)
    }

    func dismiss() {
        overlayPanel?.orderOut(nil)
        overlayPanel = nil
        overlayView = nil
        closePanel?.orderOut(nil)
        closePanel = nil
        onClose = nil
    }

    private func createOverlayPanel(screenFrame: CGRect) {
        let panel = NSPanel(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = UserDefaults.standard.bool(forKey: UserDefaultsKeys.creatorModeEnabled) ? .readOnly : .none

        let view = ZoomOverlayView(frame: screenFrame)
        panel.contentView = view

        self.overlayPanel = panel
        self.overlayView = view
    }

    private func showCloseButton(cropRect: CGRect, screenFrame: CGRect) {
        let buttonSize: CGFloat = 24
        // Position at top-right corner of crop rect
        let buttonX = cropRect.maxX - buttonSize / 2
        let buttonY = cropRect.maxY - buttonSize / 2

        if closePanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: buttonSize, height: buttonSize),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = NSWindow.Level(Int(CGShieldingWindowLevel()) + 1)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.sharingType = UserDefaults.standard.bool(forKey: UserDefaultsKeys.creatorModeEnabled) ? .readOnly : .none

            let hostingView = NSHostingView(rootView: ZoomCloseButton { [weak self] in
                self?.onClose?()
            })
            hostingView.frame = NSRect(x: 0, y: 0, width: buttonSize, height: buttonSize)
            panel.contentView = hostingView
            panel.setContentSize(NSSize(width: buttonSize, height: buttonSize))
            closePanel = panel
        }

        closePanel?.setFrameOrigin(NSPoint(x: buttonX, y: buttonY))
        closePanel?.orderFrontRegardless()
    }
}

// MARK: - Close Button View

private struct ZoomCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .blue)
        }
        .buttonStyle(.plain)
        .frame(width: 24, height: 24)
    }
}

// MARK: - Zoom Overlay View

private final class ZoomOverlayView: NSView {
    var cropRect: CGRect = .zero
    var screenFrame: CGRect = .zero

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)

        guard cropRect.width > 0, cropRect.height > 0 else { return }

        // Convert screen coordinates to view coordinates
        let localCrop = CGRect(
            x: cropRect.origin.x - screenFrame.origin.x,
            y: cropRect.origin.y - screenFrame.origin.y,
            width: cropRect.width,
            height: cropRect.height
        )

        // Dim area outside the crop region
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.25).cgColor)
        ctx.fill(bounds)
        ctx.clear(localCrop)

        // Blue border around the crop region
        ctx.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.8).cgColor)
        ctx.setLineWidth(2.5)
        ctx.stroke(localCrop.insetBy(dx: -1, dy: -1))

        // "ZOOM" label at top-left of crop region
        let label = "ZOOM" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let textSize = label.size(withAttributes: attrs)
        let badgePadding: CGFloat = 4
        let badgeRect = CGRect(
            x: localCrop.minX,
            y: localCrop.maxY + 2,
            width: textSize.width + badgePadding * 2,
            height: textSize.height + badgePadding
        )
        ctx.setFillColor(NSColor.systemBlue.withAlphaComponent(0.8).cgColor)
        let path = CGPath(roundedRect: badgeRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
        ctx.addPath(path)
        ctx.fillPath()
        label.draw(at: NSPoint(x: badgeRect.minX + badgePadding, y: badgeRect.minY + badgePadding / 2),
                   withAttributes: attrs)
    }
}
