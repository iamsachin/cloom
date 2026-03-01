import SwiftUI
import CoreImage

struct WebcamSettingsTab: View {
    @AppStorage(UserDefaultsKeys.webcamBrightness) private var webcamBrightness: Double = 0
    @AppStorage(UserDefaultsKeys.webcamContrast) private var webcamContrast: Double = 1
    @AppStorage(UserDefaultsKeys.webcamSaturation) private var webcamSaturation: Double = 1
    @AppStorage(UserDefaultsKeys.webcamHighlights) private var webcamHighlights: Double = 1
    @AppStorage(UserDefaultsKeys.webcamShadows) private var webcamShadows: Double = 0
    @AppStorage(UserDefaultsKeys.webcamTemperature) private var webcamTemperature: Double = 6500
    @AppStorage(UserDefaultsKeys.webcamTint) private var webcamTint: Double = 0
    @AppStorage(UserDefaultsKeys.webcamShape) private var webcamShapeRaw: String = "circle"
    @AppStorage(UserDefaultsKeys.webcamFrame) private var webcamFrameRaw: String = "none"

    @State private var previewImage: NSImage?
    @State private var cameraService: CameraService?
    @State private var imageAdjuster = WebcamImageAdjuster()
    private let ciContext: CIContext = SharedCIContext.instance

    private var currentShape: WebcamShape {
        WebcamShape(rawValue: webcamShapeRaw) ?? .circle
    }

    private var currentFrame: WebcamFrame {
        WebcamFrame(rawValue: webcamFrameRaw) ?? .none
    }

    /// Preview dimensions: fits inside the left panel while respecting shape aspect ratio.
    private var previewSize: CGSize {
        let maxDim: CGFloat = 180
        let ar = currentShape.aspectRatio
        if ar <= 1 {
            return CGSize(width: maxDim * ar, height: maxDim)
        } else {
            return CGSize(width: maxDim, height: maxDim / ar)
        }
    }

    private var webcamShape: Binding<WebcamShape> {
        Binding(
            get: { WebcamShape(rawValue: webcamShapeRaw) ?? .circle },
            set: { webcamShapeRaw = $0.rawValue }
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: live preview + shape/frame
            VStack(spacing: 16) {
                // Live camera preview with emoji frame
                ZStack {
                    // Emoji frame stickers (behind preview)
                    if currentFrame != .none {
                        emojiFrameView
                    }

                    // Camera preview
                    if let previewImage {
                        Image(nsImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: previewSize.width, height: previewSize.height)
                            .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius))
                    } else {
                        RoundedRectangle(cornerRadius: previewCornerRadius)
                            .fill(.quaternary)
                            .frame(width: previewSize.width, height: previewSize.height)
                            .overlay {
                                VStack(spacing: 4) {
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                    Text("Camera Preview")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.secondary)
                            }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: webcamShapeRaw)
                .animation(.easeInOut(duration: 0.2), value: webcamFrameRaw)

                // Shape picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shape")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Shape", selection: webcamShape) {
                        ForEach(WebcamShape.allCases, id: \.rawValue) { shape in
                            Text(shape.displayName).tag(shape)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel("Webcam shape")
                }

                // Emoji frame picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Frame")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(WebcamFrame.allCases, id: \.rawValue) { frame in
                            Button {
                                webcamFrameRaw = frame.rawValue
                            } label: {
                                VStack(spacing: 2) {
                                    if frame == .none {
                                        Image(systemName: "circle.dashed")
                                            .font(.system(size: 20))
                                            .frame(width: 32, height: 32)
                                    } else {
                                        Text(frame.representativeEmoji)
                                            .font(.system(size: 20))
                                            .frame(width: 32, height: 32)
                                    }
                                    Text(frame.displayName)
                                        .font(.system(size: 9))
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(webcamFrameRaw == frame.rawValue
                                              ? Color.accentColor.opacity(0.15)
                                              : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(webcamFrameRaw == frame.rawValue
                                                      ? Color.accentColor
                                                      : Color.secondary.opacity(0.3),
                                                      lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .help(frame.displayName)
                            .accessibilityLabel("\(frame.displayName) frame")
                        }
                    }
                }

                Spacer()
            }
            .frame(width: 200)
            .padding()

            Divider()

            // Right: sliders in two columns
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Image Adjustments")
                        .font(.headline)

                    HStack(alignment: .top, spacing: 24) {
                        // Column 1: Color
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Color")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            LabeledSlider(label: "Brightness", value: $webcamBrightness, range: -1...1, defaultValue: 0)
                            LabeledSlider(label: "Contrast", value: $webcamContrast, range: 0...4, defaultValue: 1)
                            LabeledSlider(label: "Saturation", value: $webcamSaturation, range: 0...2, defaultValue: 1)
                        }

                        // Column 2: Light & Tone
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Light & Tone")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            LabeledSlider(label: "Highlights", value: $webcamHighlights, range: 0...1, defaultValue: 1)
                            LabeledSlider(label: "Shadows", value: $webcamShadows, range: -1...1, defaultValue: 0)
                            LabeledSlider(label: "Temp", value: $webcamTemperature, range: 2000...10000, defaultValue: 6500)
                            LabeledSlider(label: "Tint", value: $webcamTint, range: -150...150, defaultValue: 0)
                        }
                    }

                    Button("Reset to Defaults") {
                        resetWebcamAdjustments()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .onAppear { startPreview() }
        .onDisappear { stopPreview() }
        .onChange(of: webcamBrightness) { _, _ in updateAdjuster() }
        .onChange(of: webcamContrast) { _, _ in updateAdjuster() }
        .onChange(of: webcamSaturation) { _, _ in updateAdjuster() }
        .onChange(of: webcamHighlights) { _, _ in updateAdjuster() }
        .onChange(of: webcamShadows) { _, _ in updateAdjuster() }
        .onChange(of: webcamTemperature) { _, _ in updateAdjuster() }
        .onChange(of: webcamTint) { _, _ in updateAdjuster() }
    }

    private var previewCornerRadius: CGFloat {
        currentShape.cornerRadius(forHeight: previewSize.height)
    }

    // MARK: - Emoji Frame Preview

    @ViewBuilder
    private var emojiFrameView: some View {
        let stickers = EmojiFrameRenderer.positionStickers(
            frame: currentFrame,
            bubbleWidth: previewSize.width,
            bubbleHeight: previewSize.height
        )
        let pad = EmojiFrameRenderer.framePadding(for: min(previewSize.width, previewSize.height))
        let totalW = previewSize.width + pad * 2
        let totalH = previewSize.height + pad * 2

        ZStack(alignment: .topLeading) {
            Color.clear.frame(width: totalW, height: totalH)

            ForEach(Array(stickers.enumerated()), id: \.offset) { _, sticker in
                Text(sticker.emoji)
                    .font(.system(size: sticker.fontSize))
                    // SwiftUI Y-axis is flipped relative to CG: negate Y offset from center
                    .position(
                        x: sticker.x,
                        y: totalH - sticker.y
                    )
                    .rotationEffect(.degrees(sticker.rotationDegrees))
            }
        }
        .frame(width: totalW, height: totalH)
        .allowsHitTesting(false)
    }

    private func startPreview() {
        let cam = CameraService()
        cam.onFrame = { [ciContext] _, ciImage in
            let adjusted = imageAdjuster.apply(to: ciImage)
            // Flip horizontally
            let flipped = adjusted.transformed(by: CGAffineTransform(scaleX: -1, y: 1)
                .translatedBy(x: -adjusted.extent.width, y: 0))
            guard let cgImage = ciContext.createCGImage(flipped, from: flipped.extent) else { return }
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            Task { @MainActor in
                previewImage = nsImage
            }
        }
        cam.start()
        cameraService = cam
        updateAdjuster()
    }

    private func stopPreview() {
        cameraService?.stop()
        cameraService = nil
    }

    private func updateAdjuster() {
        imageAdjuster.updateAdjustments(WebcamAdjustments(
            brightness: Float(webcamBrightness),
            contrast: Float(webcamContrast),
            saturation: Float(webcamSaturation),
            highlights: Float(webcamHighlights),
            shadows: Float(webcamShadows),
            temperature: Float(webcamTemperature),
            tint: Float(webcamTint)
        ))
    }

    private func resetWebcamAdjustments() {
        webcamBrightness = 0
        webcamContrast = 1
        webcamSaturation = 1
        webcamHighlights = 1
        webcamShadows = 0
        webcamTemperature = 6500
        webcamTint = 0
    }
}
