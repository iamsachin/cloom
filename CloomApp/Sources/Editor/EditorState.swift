import AVFoundation
import AVKit
import SwiftData
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "EditorState")

@Observable
@MainActor
final class EditorState {
    let videoRecord: VideoRecord
    let modelContext: ModelContext

    private(set) var player: AVPlayer
    private(set) var edl: EditDecisionList
    private(set) var currentTimeMs: Int64 = 0
    private(set) var isPlaying: Bool = false
    private(set) var durationMs: Int64 = 0

    // Waveform + thumbnail strip data
    private(set) var waveformPeaks: [Float] = []
    private(set) var thumbnailImages: [(timeMs: Int64, image: CGImage)] = []

    // Captions & transcript
    private(set) var captionsEnabled: Bool = false
    private(set) var showTranscript: Bool = false
    private(set) var transcriptWords: [TranscriptWordSnapshot] = []
    private(set) var chapters: [ChapterSnapshot] = []
    var bookmarks: [BookmarkSnapshot] = []

    // Cached computed collections (avoid recomputing every ~33ms tick)
    private(set) var captionPhrases: [CaptionPhrase] = []
    private(set) var transcriptSentences: [TranscriptSentence] = []

    // PiP
    @ObservationIgnored var pipController: AVPictureInPictureController?

    @ObservationIgnored nonisolated(unsafe) var timeObserverToken: Any?
    @ObservationIgnored nonisolated(unsafe) var playerRef: AVPlayer?

    init(videoRecord: VideoRecord, modelContext: ModelContext) {
        self.videoRecord = videoRecord
        self.modelContext = modelContext

        let url = URL(fileURLWithPath: videoRecord.filePath)
        let newPlayer = AVPlayer(url: url)
        self.player = newPlayer
        self.playerRef = newPlayer

        // Load or create EDL
        if let existing = videoRecord.editDecisionList {
            self.edl = existing
        } else {
            let newEDL = EditDecisionList(videoID: videoRecord.id, trimEndMs: videoRecord.durationMs)
            modelContext.insert(newEDL)
            videoRecord.editDecisionList = newEDL
            self.edl = newEDL
        }

        self.durationMs = videoRecord.durationMs

        // Load transcript words as value-type snapshots (sorted by startMs)
        if let transcript = videoRecord.transcript {
            self.transcriptWords = transcript.words
                .sorted { $0.startMs < $1.startMs }
                .map { TranscriptWordSnapshot(word: $0.word, startMs: $0.startMs, endMs: $0.endMs, confidence: $0.confidence, isFillerWord: $0.isFillerWord, isParagraphStart: $0.isParagraphStart) }
        }

        // Pre-compute caption phrases and transcript sentences from loaded words
        self.captionPhrases = CaptionOverlayView.buildPhrases(from: self.transcriptWords)
        self.transcriptSentences = TranscriptPanelView.groupIntoSentences(self.transcriptWords)

        // Load chapters as value-type snapshots (sorted by startMs)
        self.chapters = videoRecord.chapters
            .sorted { $0.startMs < $1.startMs }
            .map { ChapterSnapshot(id: $0.id, title: $0.title, startMs: $0.startMs) }

        self.bookmarks = videoRecord.bookmarks
            .sorted { $0.timestampMs < $1.timestampMs }
            .map { BookmarkSnapshot(id: $0.id, text: $0.text, timestampMs: $0.timestampMs) }

        setupTimeObserver()
        setupEndObserver()
    }

    deinit {
        if let token = timeObserverToken, let p = playerRef {
            p.removeTimeObserver(token)
        }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Time Observation

    private func setupTimeObserver() {
        let interval = CMTime(value: 1, timescale: 30) // ~33ms
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.handleTimeUpdate(time)
            }
        }
    }

    private func setupEndObserver() {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
            }
        }
    }

    private func handleTimeUpdate(_ time: CMTime) {
        let ms = Int64(time.seconds * 1000)
        currentTimeMs = ms

        // Stop at trim end
        let trimEnd = edl.trimEndMs > 0 ? edl.trimEndMs : durationMs
        if ms >= trimEnd {
            player.pause()
            isPlaying = false
            return
        }

        // Skip cut regions
        for cut in edl.cuts {
            if ms >= cut.startMs && ms < cut.endMs {
                let seekTime = CMTime(value: CMTimeValue(cut.endMs), timescale: 1000)
                player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
                return
            }
        }
    }

    // MARK: - Captions & Transcript

    func toggleCaptions() {
        captionsEnabled.toggle()
    }

    func toggleTranscript() {
        showTranscript.toggle()
    }

    // MARK: - PiP

    func togglePiP() {
        guard let pip = pipController else { return }
        if pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        } else {
            pip.startPictureInPicture()
        }
    }

    // MARK: - Playback

    func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            // If at trim end, seek to trim start
            let trimEnd = edl.trimEndMs > 0 ? edl.trimEndMs : durationMs
            if currentTimeMs >= trimEnd {
                seekTo(ms: edl.trimStartMs)
            }
            player.playImmediately(atRate: Float(edl.speedMultiplier))
        }
        isPlaying.toggle()
    }

    func seekTo(ms: Int64) {
        let time = CMTime(value: CMTimeValue(ms), timescale: 1000)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTimeMs = ms
    }

    // MARK: - Trim

    func setTrimStart(ms: Int64) {
        edl.trimStartMs = max(0, ms)
        edl.updatedAt = .now
        if currentTimeMs < ms {
            seekTo(ms: ms)
        }
        save()
    }

    func setTrimEnd(ms: Int64) {
        edl.trimEndMs = min(durationMs, ms)
        edl.updatedAt = .now
        if currentTimeMs > ms {
            seekTo(ms: ms)
        }
        save()
    }

    // MARK: - Cuts

    func addCut(startMs: Int64, endMs: Int64) {
        guard startMs < endMs else { return }
        var cuts = edl.cuts
        cuts.append(CutRange(startMs: startMs, endMs: endMs))
        cuts.sort { $0.startMs < $1.startMs }
        edl.cuts = cuts
        save()
    }

    func removeCut(id: String) {
        var cuts = edl.cuts
        cuts.removeAll { $0.id == id }
        edl.cuts = cuts
        save()
    }

    // MARK: - Speed

    func setSpeed(_ multiplier: Double) {
        edl.speedMultiplier = multiplier
        edl.updatedAt = .now
        if isPlaying {
            player.rate = Float(multiplier)
        }
        save()
    }

    // MARK: - Stitch

    func addStitchVideo(id: String) {
        var ids = edl.stitchVideoIDs
        guard !ids.contains(id) else { return }
        ids.append(id)
        edl.stitchVideoIDs = ids
        save()
    }

    func removeStitchVideo(id: String) {
        var ids = edl.stitchVideoIDs
        ids.removeAll { $0 == id }
        edl.stitchVideoIDs = ids
        save()
    }

    // MARK: - Thumbnail

    func setThumbnailTime(ms: Int64) {
        edl.thumbnailTimeMs = ms
        edl.updatedAt = .now
        save()
    }

    // MARK: - Persistence

    func save() {
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save EDL: \(error)")
        }
    }

    // MARK: - Async Loaders

    func loadWaveform() async {
        let url = URL(fileURLWithPath: videoRecord.filePath)
        let generator = WaveformGenerator()
        do {
            let peaks = try await generator.generatePeaks(from: url, peakCount: 300)
            waveformPeaks = peaks
        } catch {
            logger.error("Failed to generate waveform: \(error)")
        }
    }

    func loadThumbnailStrip() async {
        let url = URL(fileURLWithPath: videoRecord.filePath)
        let generator = ThumbnailStripGenerator()
        do {
            let images = try await generator.generate(from: url, count: 20)
            thumbnailImages = images
        } catch {
            logger.error("Failed to generate thumbnail strip: \(error)")
        }
    }
}

// MARK: - Value-Type Snapshots

struct TranscriptWordSnapshot: Identifiable {
    let id = UUID()
    let word: String
    let startMs: Int64
    let endMs: Int64
    let confidence: Float
    let isFillerWord: Bool
    let isParagraphStart: Bool
}

struct ChapterSnapshot: Identifiable {
    let id: String
    let title: String
    let startMs: Int64
}
