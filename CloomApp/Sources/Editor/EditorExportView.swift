import SwiftUI
import SwiftData
import AVFoundation
import UniformTypeIdentifiers
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "EditorExport")

struct EditorExportView: View {
    let editorState: EditorState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedQuality: VideoQuality = .medium
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportError: String?
    @State private var exportBrightness: Float = 0
    @State private var exportContrast: Float = 1
    @State private var includeSubtitles: Bool = false
    @State private var isUploading = false
    @State private var uploadShareUrl: String?
    @State private var editableTitle: String = ""
    @State private var isDeletingFromDrive = false

    private var authService: GoogleAuthService { GoogleAuthService.shared }
    private var uploadManager: DriveUploadManager { DriveUploadManager.shared }

    var body: some View {
        VStack(spacing: 20) {
            headerSection
            TextField("Title", text: $editableTitle)
                .textFieldStyle(.roundedBorder)
                .disabled(isExporting || isUploading)
            existingUploadSection
            qualitySection
            adjustmentsSection
            subtitlesToggle
            editsIndicator
            progressSection
            uploadResultSection
            errorSection
            actionButtons
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

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Spacer()
            Text("Share").font(.headline)
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
    }

    // MARK: - Existing Upload

    @ViewBuilder
    private var existingUploadSection: some View {
        let status = UploadStatus(editorState.videoRecord.uploadStatus)
        if let shareUrl = editorState.videoRecord.shareUrl, status == .uploaded {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("On Google Drive").font(.caption).foregroundStyle(.secondary)
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
                    Button(role: .destructive) { deleteFromDrive() } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .controlSize(.small)
                    .disabled(isDeletingFromDrive)
                }
            }
            Divider()
        }
    }

    // MARK: - Quality & Adjustments

    private var qualitySection: some View {
        Picker("Quality", selection: $selectedQuality) {
            ForEach(VideoQuality.allCases) { quality in
                Text(quality.label).tag(quality)
            }
        }
        .pickerStyle(.segmented)
        .disabled(isExporting)
    }

    private var adjustmentsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Video Adjustments").font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("Brightness").font(.caption).frame(width: 70, alignment: .leading)
                Slider(value: Binding(
                    get: { Double(exportBrightness) },
                    set: { exportBrightness = Float($0) }
                ), in: -1...1)
                Text(String(format: "%.2f", exportBrightness))
                    .font(.caption.monospacedDigit()).frame(width: 40)
            }
            HStack {
                Text("Contrast").font(.caption).frame(width: 70, alignment: .leading)
                Slider(value: Binding(
                    get: { Double(exportContrast) },
                    set: { exportContrast = Float($0) }
                ), in: 0...4)
                Text(String(format: "%.2f", exportContrast))
                    .font(.caption.monospacedDigit()).frame(width: 40)
            }
        }
        .disabled(isExporting)
    }

    @ViewBuilder
    private var subtitlesToggle: some View {
        if editorState.videoRecord.hasTranscript {
            Toggle("Include Subtitles", isOn: $includeSubtitles)
                .disabled(isExporting)
        }
    }

    @ViewBuilder
    private var editsIndicator: some View {
        if editorState.edl.hasEdits {
            HStack {
                Image(systemName: "scissors").foregroundStyle(.secondary)
                Text("Edits will be applied to export")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Progress & Results

    @ViewBuilder
    private var progressSection: some View {
        if isExporting {
            VStack(spacing: 8) {
                ProgressView(value: exportProgress)
                Text("Exporting \(Int(exportProgress * 100))%")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        if isUploading {
            let progress = uploadManager.uploadProgress(editorState.videoRecord.id)
            VStack(spacing: 8) {
                ProgressView(value: progress)
                Text("Uploading \(Int(progress * 100))%")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var uploadResultSection: some View {
        if let uploadShareUrl {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Uploaded!").font(.caption).foregroundStyle(.green)
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
    }

    @ViewBuilder
    private var errorSection: some View {
        if let exportError {
            Text(exportError).foregroundStyle(.red).font(.caption)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack {
            Spacer()
            Button {
                startUploadToDrive()
            } label: {
                Label("Upload to Drive", systemImage: "square.and.arrow.up")
            }
            .disabled(!authService.isSignedIn || isExporting || isUploading)
            .help(
                !authService.isSignedIn
                    ? "Sign in to Google in Settings > Cloud"
                    : "Export with settings and upload to Drive"
            )
            Button("Export") { startExport() }
                .disabled(isExporting || isUploading)
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

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

    private func startExport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = editableTitle + " (Export).mp4"

        guard panel.runModal() == .OK, let destURL = panel.url else { return }

        isExporting = true
        exportError = nil

        let filePath = editorState.videoRecord.filePath
        let edlSnapshot = EDLSnapshot(from: editorState.edl)
        let words = editorState.transcriptWords
        let duration = editorState.durationMs

        Task {
            do {
                try await ExportService.exportMP4(
                    filePath: filePath,
                    edlSnapshot: edlSnapshot,
                    transcriptWords: words,
                    durationMs: duration,
                    quality: selectedQuality,
                    brightness: exportBrightness,
                    contrast: exportContrast,
                    includeSubtitles: includeSubtitles,
                    destURL: destURL
                ) { p in exportProgress = p }
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

        let filePath = editorState.videoRecord.filePath
        let edlSnapshot = EDLSnapshot(from: editorState.edl)
        let words = editorState.transcriptWords
        let duration = editorState.durationMs

        Task {
            do {
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent("\(editableTitle) (Export).mp4")
                try? FileManager.default.removeItem(at: tempURL)

                try await ExportService.exportMP4(
                    filePath: filePath,
                    edlSnapshot: edlSnapshot,
                    transcriptWords: words,
                    durationMs: duration,
                    quality: selectedQuality,
                    brightness: exportBrightness,
                    contrast: exportContrast,
                    includeSubtitles: includeSubtitles,
                    destURL: tempURL
                ) { p in exportProgress = p }

                await uploadManager.uploadExportedFile(
                    filePath: tempURL.path,
                    videoRecord: editorState.videoRecord,
                    modelContext: modelContext
                )

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
}
