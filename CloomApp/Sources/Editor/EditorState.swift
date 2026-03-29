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
    var comments: [CommentSnapshot] = []

    // Cached computed collections (avoid recomputing every ~33ms tick)
    private(set) var captionPhrases: [CaptionPhrase] = []
    private(set) var transcriptSentences: [TranscriptSentence] = []

    // Auto-cut preview ranges (shown on timeline before applying)
    private(set) var previewCutRanges: [(startMs: Int64, endMs: Int64)] = []
    private(set) var previewCutLabel: String = ""  // "silences" or "filler words"
    var isShowingCutPreview: Bool { !previewCutRanges.isEmpty }

    // Persisted silence ranges from AI pipeline
    private(set) var silenceRanges: [SilenceRange] = []

    // Punch-in re-record markers
    private(set) var punchInMarkers: [PunchInMarker] = []

    // Transcript polling
    private(set) var isTranscribing: Bool = false
    @ObservationIgnored private var transcriptPollingTask: Task<Void, Never>?

    // Undo/Redo
    let undoManager = EDLUndoManager()

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

        self.comments = CommentSnapshot.sorted(
            videoRecord.comments.map {
                CommentSnapshot(id: $0.id, timestampMs: $0.timestampMs, text: $0.text, createdAt: $0.createdAt)
            }
        )

        self.silenceRanges = videoRecord.silenceRanges
        self.punchInMarkers = videoRecord.punchInMarkers

        setupTimeObserver()
        setupEndObserver()

        // If transcript isn't loaded yet and AI is processing, poll until it appears
        if transcriptWords.isEmpty && AIProcessingTracker.shared.isProcessing(videoRecord.id) {
            isTranscribing = true
            startTranscriptPolling()
        }
    }

    deinit {
        transcriptPollingTask?.cancel()
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

    /// Poll for transcript data using a fresh ModelContext until it appears.
    private func startTranscriptPolling() {
        transcriptPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, self.transcriptWords.isEmpty else { return }
                if self.tryLoadTranscript() {
                    self.isTranscribing = false
                    logger.info("Transcript loaded via polling")
                    return
                }
            }
        }
    }

    /// Try to load transcript from a fresh ModelContext. Returns true if transcript was found.
    @discardableResult
    private func tryLoadTranscript() -> Bool {
        let videoID = videoRecord.id
        let freshContext = ModelContext(modelContext.container)
        let predicate = #Predicate<VideoRecord> { $0.id == videoID }
        var descriptor = FetchDescriptor<VideoRecord>(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let freshVideo = try? freshContext.fetch(descriptor).first,
              let transcript = freshVideo.transcript else { return false }

        let words = transcript.words
            .sorted { $0.startMs < $1.startMs }
            .map { TranscriptWordSnapshot(word: $0.word, startMs: $0.startMs, endMs: $0.endMs, confidence: $0.confidence, isFillerWord: $0.isFillerWord, isParagraphStart: $0.isParagraphStart) }
        guard !words.isEmpty else { return false }

        self.transcriptWords = words
        self.captionPhrases = CaptionOverlayView.buildPhrases(from: words)
        self.transcriptSentences = TranscriptPanelView.groupIntoSentences(words)

        self.chapters = freshVideo.chapters
            .sorted { $0.startMs < $1.startMs }
            .map { ChapterSnapshot(id: $0.id, title: $0.title, startMs: $0.startMs) }

        self.silenceRanges = freshVideo.silenceRanges

        return true
    }

    /// Manually trigger transcript generation for this video.
    func generateTranscript() {
        guard !isTranscribing, transcriptWords.isEmpty else { return }
        isTranscribing = true
        let videoID = videoRecord.id
        let filePath = videoRecord.filePath
        let container = modelContext.container

        Task.detached {
            let orchestrator = AIOrchestrator()
            await orchestrator.runPipeline(
                videoRecordID: videoID,
                audioPath: filePath,
                modelContainer: container
            )
        }
        startTranscriptPolling()
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

    // MARK: - Shuttle Playback (J/K/L)

    private static let shuttleSpeeds: [Float] = [-8, -4, -2, -1, 1, 2, 4, 8]
    @ObservationIgnored private var shuttleIndex: Int = 4 // index 4 = 1x forward

    /// Shuttle backward: decrease speed or reverse.
    func shuttleBackward() {
        shuttleIndex = max(0, shuttleIndex - 1)
        let rate = Self.shuttleSpeeds[shuttleIndex]
        player.rate = rate
        isPlaying = rate != 0
    }

    /// Shuttle forward: increase speed.
    func shuttleForward() {
        shuttleIndex = min(Self.shuttleSpeeds.count - 1, shuttleIndex + 1)
        let rate = Self.shuttleSpeeds[shuttleIndex]
        player.rate = rate
        isPlaying = rate != 0
    }

    /// Stop shuttle (pause).
    func shuttleStop() {
        player.pause()
        isPlaying = false
        shuttleIndex = 4
    }

    // MARK: - Frame Nudge (Arrow Keys)

    /// Step backward by one frame (~33ms at 30fps).
    func nudgeBackward() {
        player.pause()
        isPlaying = false
        let ms = max(0, currentTimeMs - 33)
        seekTo(ms: ms)
    }

    /// Step forward by one frame (~33ms at 30fps).
    func nudgeForward() {
        player.pause()
        isPlaying = false
        let trimEnd = edl.trimEndMs > 0 ? edl.trimEndMs : durationMs
        let ms = min(trimEnd, currentTimeMs + 33)
        seekTo(ms: ms)
    }

    // MARK: - Trim

    func setTrimStart(ms: Int64) {
        undoManager.recordState(edl)
        edl.trimStartMs = max(0, ms)
        edl.updatedAt = .now
        if currentTimeMs < ms {
            seekTo(ms: ms)
        }
        save()
    }

    func setTrimEnd(ms: Int64) {
        undoManager.recordState(edl)
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
        undoManager.recordState(edl)
        var cuts = edl.cuts
        cuts.append(CutRange(startMs: startMs, endMs: endMs))
        cuts.sort { $0.startMs < $1.startMs }
        edl.cuts = cuts
        save()
    }

    func removeCut(id: String) {
        undoManager.recordState(edl)
        var cuts = edl.cuts
        cuts.removeAll { $0.id == id }
        edl.cuts = cuts
        save()
    }

    /// Add multiple cuts at once (single undo snapshot). Used by auto-cut features.
    func addCuts(ranges: [(startMs: Int64, endMs: Int64)]) {
        guard !ranges.isEmpty else { return }
        undoManager.recordState(edl)
        var cuts = edl.cuts
        for r in ranges where r.startMs < r.endMs {
            cuts.append(CutRange(startMs: r.startMs, endMs: r.endMs))
        }
        cuts.sort { $0.startMs < $1.startMs }
        edl.cuts = cuts
        save()
    }

    // MARK: - Speed

    func setSpeed(_ multiplier: Double) {
        undoManager.recordState(edl)
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
        undoManager.recordState(edl)
        ids.append(id)
        edl.stitchVideoIDs = ids
        save()
    }

    func removeStitchVideo(id: String) {
        undoManager.recordState(edl)
        var ids = edl.stitchVideoIDs
        ids.removeAll { $0 == id }
        edl.stitchVideoIDs = ids
        save()
    }

    // MARK: - Thumbnail

    func setThumbnailTime(ms: Int64) {
        undoManager.recordState(edl)
        edl.thumbnailTimeMs = ms
        edl.updatedAt = .now
        save()
    }

    // MARK: - Blur Regions

    func addBlurRegion(_ region: BlurRegion) {
        undoManager.recordState(edl)
        var regions = edl.blurRegions
        regions.append(region)
        edl.blurRegions = regions
        save()
    }

    func removeBlurRegion(id: String) {
        undoManager.recordState(edl)
        var regions = edl.blurRegions
        regions.removeAll { $0.id == id }
        edl.blurRegions = regions
        save()
    }

    func updateBlurRegion(_ updated: BlurRegion) {
        undoManager.recordState(edl)
        var regions = edl.blurRegions
        if let index = regions.firstIndex(where: { $0.id == updated.id }) {
            regions[index] = updated
        }
        edl.blurRegions = regions
        save()
    }

    // MARK: - Undo / Redo

    func undo() {
        if undoManager.undo(current: edl) {
            save()
        }
    }

    func redo() {
        if undoManager.redo(current: edl) {
            save()
        }
    }

    // MARK: - Auto-Cut Preview

    /// Show silence ranges as preview highlights on the timeline.
    func previewSilenceRemoval() {
        let ranges = silenceRanges.map { (startMs: $0.startMs, endMs: $0.endMs) }
        previewCutRanges = ranges
        previewCutLabel = "silences"
    }

    /// Show filler word ranges as preview highlights on the timeline.
    func previewFillerRemoval() {
        let ranges = transcriptWords
            .filter { $0.isFillerWord }
            .map { (startMs: $0.startMs, endMs: $0.endMs) }
        previewCutRanges = ranges
        previewCutLabel = "filler words"
    }

    /// Apply the previewed cut ranges as actual EDL cuts.
    func applyPreviewedCuts() {
        addCuts(ranges: previewCutRanges)
        previewCutRanges = []
        previewCutLabel = ""
    }

    /// Dismiss the preview without applying.
    func dismissCutPreview() {
        previewCutRanges = []
        previewCutLabel = ""
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
        let path = videoRecord.filePath
        guard FileManager.default.fileExists(atPath: path) else {
            logger.warning("Video file missing at \(path) — skipping waveform generation")
            return
        }
        let url = URL(fileURLWithPath: path)
        let generator = WaveformGenerator()
        do {
            let sensitivity = UserDefaults.standard.integer(forKey: UserDefaultsKeys.micSensitivity)
            let peaks = try await generator.generatePeaks(from: url, peakCount: 1500, micSensitivity: sensitivity > 0 ? sensitivity : 100)
            waveformPeaks = peaks
        } catch {
            logger.error("Failed to generate waveform: \(error)")
        }
    }

    func loadThumbnailStrip() async {
        let path = videoRecord.filePath
        guard FileManager.default.fileExists(atPath: path) else {
            logger.warning("Video file missing at \(path) — skipping thumbnail strip generation")
            return
        }
        let url = URL(fileURLWithPath: path)
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

struct TranscriptWordSnapshot: Identifiable, Sendable {
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
