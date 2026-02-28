import SwiftUI
import SwiftData
import AVFoundation
import CoreImage
import UniformTypeIdentifiers
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "EditorExport")

enum ExportFormat: String, CaseIterable, Identifiable {
    case mp4 = "MP4"
    case gif = "GIF"
    var id: String { rawValue }
}

struct EditorExportView: View {
    let editorState: EditorState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedFormat: ExportFormat = .mp4
    @State private var selectedQuality: VideoQuality = .medium
    @State private var gifWidth: Int = 480
    @State private var gifFPS: Int = 15
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportError: String?
    @State private var exportBrightness: Float = 0
    @State private var exportContrast: Float = 1
    @State private var subtitleMode: SubtitleMode = .none
    @State private var isUploading = false
    @State private var uploadShareUrl: String?
    @State private var editableTitle: String = ""
    @State private var isDeletingFromDrive = false

    private var authService: GoogleAuthService { GoogleAuthService.shared }
    private var uploadManager: DriveUploadManager { DriveUploadManager.shared }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Text("Share")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(isExporting || isUploading)
            }

            // Editable title
            TextField("Title", text: $editableTitle)
                .textFieldStyle(.roundedBorder)
                .disabled(isExporting || isUploading)

            // Existing Drive upload
            existingUploadSection

            // Format picker
            Picker("Format", selection: $selectedFormat) {
                ForEach(ExportFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isExporting)

            // Format-specific options
            if selectedFormat == .mp4 {
                Picker("Quality", selection: $selectedQuality) {
                    ForEach(VideoQuality.allCases) { quality in
                        Text(quality.label).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(isExporting)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Video Adjustments")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Brightness")
                            .font(.caption)
                            .frame(width: 70, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(exportBrightness) },
                            set: { exportBrightness = Float($0) }
                        ), in: -1...1)
                        Text(String(format: "%.2f", exportBrightness))
                            .font(.caption.monospacedDigit())
                            .frame(width: 40)
                    }

                    HStack {
                        Text("Contrast")
                            .font(.caption)
                            .frame(width: 70, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(exportContrast) },
                            set: { exportContrast = Float($0) }
                        ), in: 0...4)
                        Text(String(format: "%.2f", exportContrast))
                            .font(.caption.monospacedDigit())
                            .frame(width: 40)
                    }
                }
                .disabled(isExporting)

                if editorState.videoRecord.hasTranscript {
                    Picker("Subtitles", selection: $subtitleMode) {
                        ForEach(SubtitleMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .disabled(isExporting)
                }
            } else {
                HStack {
                    Text("Width:")
                    TextField("Width", value: $gifWidth, format: .number)
                        .frame(width: 60)
                    Text("px")

                    Spacer()

                    Text("FPS:")
                    TextField("FPS", value: $gifFPS, format: .number)
                        .frame(width: 40)
                }
                .disabled(isExporting)
            }

            // Edits summary
            if editorState.edl.hasEdits {
                HStack {
                    Image(systemName: "scissors")
                        .foregroundStyle(.secondary)
                    Text("Edits will be applied to export")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isExporting {
                VStack(spacing: 8) {
                    ProgressView(value: exportProgress)
                    Text("Exporting \(Int(exportProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isUploading {
                let progress = uploadManager.uploadProgress(editorState.videoRecord.id)
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                    Text("Uploading \(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let uploadShareUrl {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Uploaded!")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Copy Link") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(uploadShareUrl, forType: .string)
                    }
                    .controlSize(.small)
                    Button("Open") {
                        if let url = URL(string: uploadShareUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                }
            }

            if let exportError {
                Text(exportError)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Spacer()
                Button {
                    startUploadToDrive()
                } label: {
                    Label("Upload to Drive", systemImage: "square.and.arrow.up")
                }
                .disabled(
                    !authService.isSignedIn
                    || selectedFormat == .gif
                    || isExporting
                    || isUploading
                )
                .help(
                    !authService.isSignedIn
                        ? "Sign in to Google in Settings > Cloud"
                        : selectedFormat == .gif
                            ? "Upload not available for GIF"
                            : "Export with settings and upload to Drive"
                )
                Button("Export") { startExport() }
                    .disabled(isExporting || isUploading)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            editableTitle = editorState.videoRecord.title
            authService.restoreSessionIfNeeded()
        }
        .onChange(of: editableTitle) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                editorState.videoRecord.title = trimmed
            }
        }
    }

    // MARK: - Existing Upload Section

    @ViewBuilder
    private var existingUploadSection: some View {
        let status = UploadStatus(editorState.videoRecord.uploadStatus)
        if let shareUrl = editorState.videoRecord.shareUrl, status == .uploaded {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("On Google Drive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Copy Link") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(shareUrl, forType: .string)
                    }
                    .controlSize(.small)
                    Button("Open") {
                        if let url = URL(string: shareUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                    Button(role: .destructive) {
                        deleteFromDrive()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .controlSize(.small)
                    .disabled(isDeletingFromDrive)
                }
            }

            Divider()
        }
    }

    // MARK: - Delete from Drive

    private func deleteFromDrive() {
        isDeletingFromDrive = true
        Task {
            if let fileId = editorState.videoRecord.driveFileId,
               let token = await GoogleAuthService.shared.refreshTokenIfNeeded() {
                try? await DriveUploadService().deleteFile(fileId: fileId, accessToken: token)
            }
            editorState.videoRecord.driveFileId = nil
            editorState.videoRecord.shareUrl = nil
            editorState.videoRecord.uploadStatus = nil
            editorState.videoRecord.uploadedAt = nil
            try? modelContext.save()
            isDeletingFromDrive = false
            uploadShareUrl = nil
        }
    }

    // MARK: - Export

    private func startExport() {
        let panel = NSSavePanel()

        if selectedFormat == .mp4 {
            panel.allowedContentTypes = [.mpeg4Movie]
            panel.nameFieldStringValue = editableTitle + " (Export).mp4"
        } else {
            panel.allowedContentTypes = [.gif]
            panel.nameFieldStringValue = editableTitle + " (Export).gif"
        }

        guard panel.runModal() == .OK, let destURL = panel.url else { return }

        isExporting = true
        exportError = nil

        Task {
            do {
                if selectedFormat == .mp4 {
                    try await exportMP4(to: destURL)
                } else {
                    try await exportGIF(to: destURL)
                }
                exportProgress = 1.0
                try? await Task.sleep(for: .milliseconds(500))
                dismiss()
            } catch {
                exportError = error.localizedDescription
                isExporting = false
            }
        }
    }

    private func startUploadToDrive() {
        isUploading = true
        exportError = nil
        uploadShareUrl = nil

        Task {
            do {
                // Export to temp file with all settings applied
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent(
                    "\(editableTitle) (Export).mp4"
                )

                // Remove stale temp file if exists
                try? FileManager.default.removeItem(at: tempURL)

                try await exportMP4(to: tempURL)

                // Upload the exported file (manager handles temp cleanup)
                await uploadManager.uploadExportedFile(
                    filePath: tempURL.path,
                    videoRecord: editorState.videoRecord,
                    modelContext: modelContext
                )

                // Check result
                if let shareUrl = editorState.videoRecord.shareUrl {
                    uploadShareUrl = shareUrl
                } else {
                    exportError = "Upload failed — check Settings > Cloud"
                }
                isUploading = false
            } catch {
                exportError = error.localizedDescription
                isUploading = false
            }
        }
    }

    private func exportMP4(to destURL: URL) async throws {
        let builder = EditorCompositionBuilder()
        let sourceURL = URL(fileURLWithPath: editorState.videoRecord.filePath)
        let snapshot = EDLSnapshot(from: editorState.edl)

        let result = try await builder.build(
            edl: snapshot,
            sourceURL: sourceURL,
            stitchURLs: []
        )

        guard let session = AVAssetExportSession(
            asset: result.composition,
            presetName: presetForQuality(selectedQuality)
        ) else {
            throw NSError(domain: "EditorExport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])
        }

        // Apply audio mix for multi-track audio
        if let audioMix = result.audioMix {
            session.audioMix = audioMix
        }

        // Build subtitle phrases if needed
        var subtitlePhrases: [SubtitlePhrase] = []
        if subtitleMode.needsHardBurn || subtitleMode.needsSRT {
            let subtitleService = SubtitleExportService()
            subtitlePhrases = await subtitleService.buildPhrases(
                from: editorState.transcriptWords,
                edl: snapshot,
                totalDurationMs: editorState.durationMs
            )
        }

        // Apply video composition if brightness/contrast or hard-burn subtitles needed
        let needsAdjustment = exportBrightness != 0 || exportContrast != 1
        let needsHardBurn = subtitleMode.needsHardBurn && !subtitlePhrases.isEmpty

        if needsAdjustment || needsHardBurn {
            let brightness = exportBrightness
            let contrast = exportContrast
            let phrases = subtitlePhrases
            let ciContext = CIContext(options: [.useSoftwareRenderer: false])

            // Pre-render all subtitle images once (instead of per-frame)
            let subtitleCache: [CIImage?]
            if needsHardBurn {
                let videoTracks = try await result.composition.loadTracks(withMediaType: .video)
                if let videoTrack = videoTracks.first {
                    let size = try await videoTrack.load(.naturalSize)
                    let rendered = SubtitleExportService.prerenderImages(
                        phrases: phrases,
                        videoWidth: size.width,
                        videoHeight: size.height
                    )
                    logger.info("Pre-rendered \(rendered.count) subtitle images")
                    subtitleCache = rendered
                } else {
                    subtitleCache = []
                }
            } else {
                subtitleCache = []
            }

            let videoComp = try await AVVideoComposition(
                applyingFiltersTo: result.composition
            ) { params in
                var image = params.sourceImage.clampedToExtent()

                // Apply brightness/contrast
                if needsAdjustment {
                    image = image.applyingFilter("CIColorControls", parameters: [
                        kCIInputBrightnessKey: brightness,
                        kCIInputContrastKey: contrast,
                    ])
                }

                image = image.cropped(to: params.sourceImage.extent)

                // Burn pre-rendered subtitle overlay
                if needsHardBurn {
                    let frameTimeMs = Int64(params.compositionTime.seconds * 1000)
                    image = SubtitleExportService.burnSubtitle(
                        onto: image,
                        phrases: phrases,
                        cache: subtitleCache,
                        frameTimeMs: frameTimeMs
                    )
                }

                return AVCIImageFilteringResult(resultImage: image, ciContext: ciContext)
            }
            session.videoComposition = videoComp
        }

        try await session.export(to: destURL, as: .mp4)

        // Generate SRT sidecar if requested
        if subtitleMode.needsSRT && !subtitlePhrases.isEmpty {
            let srtURL = destURL.deletingPathExtension().appendingPathExtension("srt")
            let subtitleService = SubtitleExportService()
            try await subtitleService.generateSRT(phrases: subtitlePhrases, outputURL: srtURL)
        }
    }

    private func exportGIF(to destURL: URL) async throws {
        let service = GifExportService()
        let sourceURL = URL(fileURLWithPath: editorState.videoRecord.filePath)
        let snapshot = EDLSnapshot(from: editorState.edl)

        try await service.export(
            sourceURL: sourceURL,
            edl: snapshot,
            outputURL: destURL,
            width: gifWidth,
            fps: gifFPS
        ) { progress in
            Task { @MainActor in
                exportProgress = progress
            }
        }
    }

    private func presetForQuality(_ quality: VideoQuality) -> String {
        switch quality {
        case .low: AVAssetExportPresetMediumQuality
        case .medium: AVAssetExportPresetHighestQuality
        case .high: AVAssetExportPresetHighestQuality
        }
    }
}
