import SwiftUI

struct AnnotationToolbarContentView: View {
    @State private var selectedTool: AnnotationTool
    @State private var selectedColor: StrokeColor
    @State private var lineWidth: CGFloat
    @State private var showColorPicker = false
    @State private var customColor: Color = .white

    let onToolChanged: (AnnotationTool) -> Void
    let onColorChanged: (StrokeColor) -> Void
    let onLineWidthChanged: (CGFloat) -> Void
    let onUndo: () -> Void
    let onClearAll: () -> Void
    let onDismiss: () -> Void

    init(
        initialTool: AnnotationTool,
        initialColor: StrokeColor,
        initialLineWidth: CGFloat,
        onToolChanged: @escaping (AnnotationTool) -> Void,
        onColorChanged: @escaping (StrokeColor) -> Void,
        onLineWidthChanged: @escaping (CGFloat) -> Void,
        onUndo: @escaping () -> Void,
        onClearAll: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self._selectedTool = State(initialValue: initialTool)
        self._selectedColor = State(initialValue: initialColor)
        self._lineWidth = State(initialValue: initialLineWidth)
        self.onToolChanged = onToolChanged
        self.onColorChanged = onColorChanged
        self.onLineWidthChanged = onLineWidthChanged
        self.onUndo = onUndo
        self.onClearAll = onClearAll
        self.onDismiss = onDismiss
    }

    private var isCustomColor: Bool {
        !StrokeColor.palette.contains(selectedColor)
    }

    var body: some View {
        HStack(spacing: 6) {
            toolButton(.pen, icon: "pencil", label: "Pen")
            toolButton(.highlighter, icon: "highlighter", label: "Highlighter")
            toolButton(.text, icon: "textformat", label: "Text")
            toolButton(.arrow, icon: "arrow.up.right", label: "Arrow")
            toolButton(.line, icon: "line.diagonal", label: "Line")
            toolButton(.rectangle, icon: "rectangle", label: "Rectangle")
            toolButton(.ellipse, icon: "circle", label: "Ellipse")
            toolButton(.eraser, icon: "eraser", label: "Eraser")

            Divider().frame(height: 20)

            ForEach(Array(StrokeColor.palette.enumerated()), id: \.offset) { _, color in
                colorSwatch(color)
            }

            // Custom color button
            Button {
                showColorPicker.toggle()
            } label: {
                ZStack {
                    if isCustomColor {
                        Circle()
                            .fill(Color(cgColor: selectedColor.cgColor))
                            .frame(width: 14, height: 14)
                        Circle()
                            .stroke(.white, lineWidth: 2)
                            .frame(width: 18, height: 18)
                    } else {
                        Circle()
                            .fill(
                                AngularGradient(
                                    colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                                    center: .center
                                )
                            )
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Custom color")
            .accessibilityLabel("Custom color picker")
            .popover(isPresented: $showColorPicker) {
                colorPickerPopover
            }

            Divider().frame(height: 20)

            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Undo")
            .accessibilityLabel("Undo")

            Button(action: onClearAll) {
                Image(systemName: "trash")
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Clear all")
            .accessibilityLabel("Clear all annotations")

            Divider().frame(height: 20)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Close annotations")
            .accessibilityLabel("Close annotations")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .cloomGlassCapsule()
    }

    private var colorPickerPopover: some View {
        VStack(spacing: 12) {
            ColorPicker("Color", selection: $customColor, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: customColor) {
                    let nsColor = NSColor(customColor)
                    let strokeColor = StrokeColor(nsColor: nsColor)
                    selectedColor = strokeColor
                    onColorChanged(strokeColor)
                }

            HStack {
                Text("#")
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .monospaced))
                TextField("Hex", text: .init(
                    get: { selectedColor.hexString.dropFirst().description },
                    set: { newValue in
                        if let color = StrokeColor(hex: newValue) {
                            selectedColor = color
                            customColor = Color(cgColor: color.cgColor)
                            onColorChanged(color)
                        }
                    }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(width: 70)
                .textFieldStyle(.roundedBorder)
            }
        }
        .padding(12)
        .frame(width: 200)
    }

    private func toolButton(_ tool: AnnotationTool, icon: String, label: String) -> some View {
        Button {
            selectedTool = tool
            onToolChanged(tool)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(selectedTool == tool ? .blue : .white)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel("\(label) tool")
    }

    private func colorSwatch(_ color: StrokeColor) -> some View {
        Button {
            selectedColor = color
            onColorChanged(color)
        } label: {
            Circle()
                .fill(Color(cgColor: color.cgColor))
                .frame(width: 14, height: 14)
                .overlay {
                    if selectedColor == color {
                        Circle()
                            .stroke(.white, lineWidth: 2)
                            .frame(width: 18, height: 18)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(color.displayName) color")
    }
}
