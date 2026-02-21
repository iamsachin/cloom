import AVFoundation
import Foundation
import SwiftData
import AppKit
import UserNotifications
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "AIOrchestrator")

actor AIOrchestrator {

    /// Run the full AI pipeline for a recorded video.
    ///
    /// Runs transcription, filler detection, title/summary/chapter generation,
    /// and silence detection. Results are persisted to SwiftData.
    /// Fails silently if no API key is configured or auto-transcribe is disabled.
    func runPipeline(
        videoRecordID: String,
        audioPath: String,
        modelContainer: ModelContainer
    ) async {
        // Check API key
        guard let apiKey = KeychainService.loadAPIKey(), !apiKey.isEmpty else {
            logger.info("No API key configured — skipping AI pipeline")
            return
        }

        // Check auto-transcribe setting (default to true if never set)
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "aiAutoTranscribe") == nil {
            defaults.set(true, forKey: "aiAutoTranscribe")
        }
        guard defaults.bool(forKey: "aiAutoTranscribe") else {
            logger.info("Auto-transcribe disabled — skipping AI pipeline")
            return
        }

        logger.info("Starting AI pipeline for video \(videoRecordID)")
        await AIProcessingTracker.shared.startProcessing(videoRecordID)
        showNotification(title: "AI Processing", message: "Transcribing recording...")

        // Step 0: Extract audio from MP4 (mic track preferred, falls back to mix)
        let extractedAudioPath: String
        do {
            extractedAudioPath = try await extractAudio(from: audioPath)
            logger.info("Extracted audio to \(extractedAudioPath)")
        } catch {
            logger.error("Audio extraction failed: \(error) — falling back to video file")
            extractedAudioPath = audioPath
        }

        // Step 1: Transcription
        let transcript: Transcript
        do {
            transcript = try transcribeAudio(
                audioPath: extractedAudioPath,
                apiKey: apiKey,
                provider: .openAi,
                model: ""
            )
            logger.info("Transcription complete: \(transcript.words.count) words")
        } catch {
            logger.error("Transcription failed: \(error)")
            await AIProcessingTracker.shared.stopProcessing(videoRecordID)
            await showError("Transcription Failed", detail: "\(error)")
            return
        }

        // Check if transcript has meaningful content
        let trimmedText = transcript.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasEnoughText = trimmedText.count >= 10

        // Step 2: Filler word detection
        let fillerWords: [FillerWord]
        do {
            let transcriptWords = transcript.words.map { w in
                TranscriptWord(
                    word: w.word,
                    startMs: w.startMs,
                    endMs: w.endMs,
                    confidence: w.confidence
                )
            }
            fillerWords = identifyFillerWords(words: transcriptWords)
            logger.info("Found \(fillerWords.count) filler words")
        }

        // Step 3-5: Only call LLM if transcript has meaningful text
        var generatedTitle: String?
        var generatedSummary: String?
        var generatedChapters: [Chapter] = []

        if hasEnoughText {
            // Step 3: Generate title
            do {
                generatedTitle = try generateTitle(
                    transcriptText: transcript.fullText,
                    apiKey: apiKey,
                    provider: .openAi
                )
                logger.info("Generated title: \(generatedTitle ?? "")")
            } catch {
                logger.error("Title generation failed: \(error)")
                await showError("Title Generation Failed", detail: "\(error)")
            }

            // Step 4: Generate summary
            do {
                generatedSummary = try generateSummary(
                    transcriptText: transcript.fullText,
                    apiKey: apiKey,
                    provider: .openAi
                )
                logger.info("Generated summary")
            } catch {
                logger.error("Summary generation failed: \(error)")
                await showError("Summary Generation Failed", detail: "\(error)")
            }

            // Step 5: Generate chapters
            do {
                generatedChapters = try generateChapters(
                    transcriptText: transcript.fullText,
                    apiKey: apiKey,
                    provider: .openAi
                )
                logger.info("Generated \(generatedChapters.count) chapters")
            } catch {
                logger.error("Chapter generation failed: \(error)")
                await showError("Chapter Generation Failed", detail: "\(error)")
            }
        } else {
            logger.info("Transcript too short (\(trimmedText.count) chars) — skipping LLM steps")
        }

        // Step 6: Silence detection
        var silentRanges: [TimeRange] = []
        do {
            silentRanges = try detectSilence(
                audioPath: extractedAudioPath,
                thresholdDb: -40.0,
                minDurationMs: 500
            )
            logger.info("Found \(silentRanges.count) silent regions")
        } catch {
            logger.error("Silence detection failed: \(error)")
            await showError("Silence Detection Failed", detail: "\(error)")
        }

        // Step 7: Persist results to SwiftData
        await persistResults(
            videoRecordID: videoRecordID,
            transcript: transcript,
            fillerWords: fillerWords,
            generatedTitle: generatedTitle,
            generatedSummary: generatedSummary,
            generatedChapters: generatedChapters,
            modelContainer: modelContainer
        )

        await AIProcessingTracker.shared.stopProcessing(videoRecordID)
        showNotification(title: "AI Processing Complete", message: "Transcript and summary ready.")
        logger.info("AI pipeline complete for video \(videoRecordID)")
    }

    // MARK: - Audio Extraction

    /// Extract audio from MP4 to a temporary .m4a file.
    /// Prefers the mic audio track (second audio track) over system audio.
    /// Falls back to mixing all audio tracks if only one exists.
    private func extractAudio(from videoPath: String) async throws -> String {
        let videoURL = URL(fileURLWithPath: videoPath)
        let asset = AVURLAsset(url: videoURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        guard !audioTracks.isEmpty else {
            throw NSError(domain: "AIOrchestrator", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No audio tracks found in video"
            ])
        }

        // Create a composition with just the desired audio track
        let composition = AVMutableComposition()
        let duration = try await asset.load(.duration)

        if audioTracks.count >= 2 {
            // Multiple audio tracks: use the second one (mic audio)
            // Track order in VideoWriter: video(0), systemAudio(1), micAudio(2)
            // But loadTracks(.audio) only returns audio tracks, so mic = index 1
            let micTrack = audioTracks[1]
            if let compositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                try compositionTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: micTrack,
                    at: .zero
                )
            }
            logger.info("Using mic audio track (track 2 of \(audioTracks.count) audio tracks)")
        } else {
            // Single audio track — use it directly
            let track = audioTracks[0]
            if let compositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                try compositionTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: track,
                    at: .zero
                )
            }
            logger.info("Using single audio track")
        }

        // Export to temporary .m4a file
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("cloom_audio_\(UUID().uuidString).m4a")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw NSError(domain: "AIOrchestrator", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create export session"
            ])
        }

        try await exportSession.export(to: outputURL, as: .m4a)

        return outputURL.path
    }

    @MainActor
    private func showError(_ title: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showNotification(title: String, message: String) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "notificationsEnabled") != nil {
            guard defaults.bool(forKey: "notificationsEnabled") else { return }
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    @MainActor
    private func persistResults(
        videoRecordID: String,
        transcript: Transcript,
        fillerWords: [FillerWord],
        generatedTitle: String?,
        generatedSummary: String?,
        generatedChapters: [Chapter],
        modelContainer: ModelContainer
    ) {
        let context = ModelContext(modelContainer)

        // Fetch the video record
        let predicate = #Predicate<VideoRecord> { $0.id == videoRecordID }
        var descriptor = FetchDescriptor<VideoRecord>(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let video = try? context.fetch(descriptor).first else {
            logger.error("Video record not found: \(videoRecordID)")
            return
        }

        // Build filler word set for fast lookup
        let fillerSet = Set(fillerWords.map { "\($0.startMs)-\($0.endMs)" })

        // Create transcript record
        let transcriptRecord = TranscriptRecord(
            videoID: videoRecordID,
            fullText: transcript.fullText,
            language: transcript.language
        )
        context.insert(transcriptRecord)

        // Create word records
        for w in transcript.words {
            let isFiller = fillerSet.contains("\(w.startMs)-\(w.endMs)")
            let wordRecord = TranscriptWordRecord(
                word: w.word,
                startMs: w.startMs,
                endMs: w.endMs,
                confidence: w.confidence,
                isFillerWord: isFiller
            )
            wordRecord.transcript = transcriptRecord
            context.insert(wordRecord)
        }

        // Link transcript to video
        video.transcript = transcriptRecord
        video.hasTranscript = true

        // Update title and summary
        if let title = generatedTitle {
            video.title = title
        }
        if let summary = generatedSummary {
            video.summary = summary
        }

        // Create chapter records
        for ch in generatedChapters {
            let chapterRecord = ChapterRecord(
                id: ch.id,
                title: ch.title,
                startMs: ch.startMs
            )
            chapterRecord.video = video
            context.insert(chapterRecord)
        }

        video.updatedAt = .now

        do {
            try context.save()
            logger.info("Persisted AI results for video \(videoRecordID)")
        } catch {
            logger.error("Failed to save AI results: \(error)")
        }
    }
}
