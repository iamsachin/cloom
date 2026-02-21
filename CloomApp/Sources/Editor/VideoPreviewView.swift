import SwiftUI
import AVFoundation
import AVKit

struct VideoPreviewView: NSViewRepresentable {
    let player: AVPlayer
    let onTap: () -> Void
    var onPiPControllerReady: ((AVPictureInPictureController) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> AVPlayerLayerView {
        let view = AVPlayerLayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.onTap = onTap

        // Create PiP controller if supported
        if AVPictureInPictureController.isPictureInPictureSupported() {
            let pipController = AVPictureInPictureController(playerLayer: view.playerLayer)
            context.coordinator.pipController = pipController
            onPiPControllerReady?(pipController!)
        }

        return view
    }

    func updateNSView(_ nsView: AVPlayerLayerView, context: Context) {
        nsView.playerLayer.player = player
    }

    class Coordinator {
        var pipController: AVPictureInPictureController?
    }
}

final class AVPlayerLayerView: NSView {
    let playerLayer = AVPlayerLayer()
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(playerLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }

    override func mouseDown(with event: NSEvent) {
        onTap?()
    }
}
