import SwiftUI
import SwiftData
import AVKit

struct PlayerView: View {
    let videoID: String

    @Query private var videos: [VideoRecord]
    @State private var player: AVPlayer?
    @State private var showExportSheet = false

    init(videoID: String) {
        self.videoID = videoID
        let id = videoID
        _videos = Query(filter: #Predicate<VideoRecord> { $0.id == id })
    }

    private var video: VideoRecord? {
        videos.first
    }

    var body: some View {
        Group {
            if let video {
                videoPlayerView(for: video)
            } else {
                ContentUnavailableView(
                    "Video Not Found",
                    systemImage: "film.fill",
                    description: Text("The requested video could not be loaded.")
                )
            }
        }
        .frame(minWidth: 640, minHeight: 400)
        .toolbar {
            if video != nil {
                Button("Export...") {
                    showExportSheet = true
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            if let video {
                ExportSheetView(sourceURL: URL(fileURLWithPath: video.filePath))
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    @ViewBuilder
    private func videoPlayerView(for video: VideoRecord) -> some View {
        VideoPlayer(player: player)
            .onAppear {
                let url = URL(fileURLWithPath: video.filePath)
                let newPlayer = AVPlayer(url: url)
                self.player = newPlayer
                newPlayer.play()
            }
            .navigationTitle(video.title)
    }
}

// MARK: - Export Sheet

private struct ExportSheetView: View {
    let sourceURL: URL
    @Environment(\.dismiss) private var dismiss

    @State private var selectedQuality: VideoQuality = .medium
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportError: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Export Recording")
                .font(.headline)

            Picker("Quality", selection: $selectedQuality) {
                ForEach(VideoQuality.allCases) { quality in
                    Text(quality.label).tag(quality)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isExporting)

            if isExporting {
                VStack(spacing: 8) {
                    ProgressView(value: exportProgress)
                    Text("\(Int(exportProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let exportError {
                Text(exportError)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isExporting)

                Spacer()

                Button("Export") {
                    startExport()
                }
                .disabled(isExporting)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    private func startExport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent + " (Export).mp4"

        guard panel.runModal() == .OK, let destURL = panel.url else { return }

        isExporting = true
        exportError = nil

        Task {
            let asset = AVURLAsset(url: sourceURL)

            guard let session = AVAssetExportSession(
                asset: asset,
                presetName: presetForQuality(selectedQuality)
            ) else {
                exportError = "Could not create export session"
                isExporting = false
                return
            }

            do {
                try await session.export(to: destURL, as: .mp4)
                exportProgress = 1.0
                try? await Task.sleep(for: .milliseconds(500))
                dismiss()
            } catch {
                exportError = error.localizedDescription
                isExporting = false
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
