import SwiftUI
import CoreImage

struct WebcamSettingsTab: View {
    @AppStorage("webcamBrightness") private var webcamBrightness: Double = 0
    @AppStorage("webcamContrast") private var webcamContrast: Double = 1
    @AppStorage("webcamSaturation") private var webcamSaturation: Double = 1
    @AppStorage("webcamHighlights") private var webcamHighlights: Double = 1
    @AppStorage("webcamShadows") private var webcamShadows: Double = 0
    @AppStorage("webcamTemperature") private var webcamTemperature: Double = 6500
    @AppStorage("webcamTint") private var webcamTint: Double = 0
    @AppStorage("webcamShape") private var webcamShapeRaw: String = "circle"
    @AppStorage("webcamBubbleTheme") private var webcamThemeRaw: String = "none"

    @State private var previewImage: NSImage?
    @State private var cameraService: CameraService?
    @State private var imageAdjuster = WebcamImageAdjuster()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private var currentShape: WebcamShape {
        WebcamShape(rawValue: webcamShapeRaw) ?? .circle
    }

    private var currentTheme: BubbleTheme {
        BubbleTheme(rawValue: webcamThemeRaw) ?? .none
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
            // Left: live preview + shape/theme
            VStack(spacing: 16) {
                // Live camera preview with theme ring
                ZStack {
                    // Theme border ring (behind preview)
                    if currentTheme != .none {
                        themeRingView
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
                .animation(.easeInOut(duration: 0.2), value: webcamThemeRaw)

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

                // Theme swatches
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bubble Theme")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 4), count: 5), spacing: 4) {
                        ForEach(BubbleTheme.allCases, id: \.rawValue) { theme in
                            Button {
                                webcamThemeRaw = theme.rawValue
                            } label: {
                                if theme == .none {
                                    Circle()
                                        .strokeBorder(Color.secondary, lineWidth: 1)
                                        .frame(width: 22, height: 22)
                                        .overlay {
                                            if webcamThemeRaw == theme.rawValue {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 8, weight: .bold))
                                            }
                                        }
                                } else {
                                    Circle()
                                        .fill(Color(nsColor: theme.swatchColor()))
                                        .frame(width: 22, height: 22)
                                        .overlay {
                                            if webcamThemeRaw == theme.rawValue {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                }
                            }
                            .buttonStyle(.plain)
                            .help(theme.displayName)
                            .accessibilityLabel("\(theme.displayName) theme")
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

    // MARK: - Theme Ring

    @ViewBuilder
    private var themeRingView: some View {
        let borderWidth: CGFloat = 5
        let ringWidth = previewSize.width + borderWidth * 2
        let ringHeight = previewSize.height + borderWidth * 2
        let ringRadius = previewCornerRadius + borderWidth

        if let (c1, c2) = currentTheme.gradientCGColors() {
            RoundedRectangle(cornerRadius: ringRadius)
                .fill(LinearGradient(
                    colors: [Color(cgColor: c1), Color(cgColor: c2)],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                ))
                .frame(width: ringWidth, height: ringHeight)
        } else if let c = currentTheme.cgColor() {
            RoundedRectangle(cornerRadius: ringRadius)
                .fill(Color(cgColor: c))
                .frame(width: ringWidth, height: ringHeight)
        }
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

// MARK: - Labeled Slider

struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double

    private var isDefault: Bool {
        abs(value - defaultValue) < 0.01
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(isDefault ? .secondary : .accentColor)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            value = defaultValue
                        }
                    }
                    .help("Click to reset")
            }
            Slider(value: $value, in: range)
        }
    }
}
