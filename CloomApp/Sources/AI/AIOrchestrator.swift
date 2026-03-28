import AVFoundation
import Foundation
import SwiftData
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
        if defaults.object(forKey: UserDefaultsKeys.aiAutoTranscribe) == nil {
            defaults.set(true, forKey: UserDefaultsKeys.aiAutoTranscribe)
        }
        guard defaults.bool(forKey: UserDefaultsKeys.aiAutoTranscribe) else {
            logger.info("Auto-transcribe disabled — skipping AI pipeline")
            return
        }

        logger.info("Starting AI pipeline for video \(videoRecordID)")
        await AIProcessingTracker.shared.startProcessing(videoRecordID)
        NotificationService.post(title: "AI Processing", body: "Transcribing recording...")

        // Step 0: Extract audio from MP4 (mic track preferred, falls back to mix)
        let extractedAudioPath: String
        do {
            extractedAudioPath = try await extractAudioFromVideo(videoPath: audioPath)
            logger.info("Extracted audio to \(extractedAudioPath)")
        } catch {
            logger.error("Audio extraction failed: \(error) — falling back to video file")
            extractedAudioPath = audioPath
        }

        // Step 1: Transcription (with chunking for large files)
        let transcript: Transcript
        do {
            let chunks = try await splitAudioForTranscription(audioPath: extractedAudioPath)
            if chunks.count > 1 {
                logger.info("Audio split into \(chunks.count) chunks for transcription")
                let paths = chunks.map(\.path)
                let offsets = chunks.map(\.offsetMs)
                transcript = try transcribeAudioChunked(
                    chunkPaths: paths,
                    offsetMs: offsets,
                    apiKey: apiKey,
                    provider: .openAi,
                    model: ""
                )
                // Clean up chunk files
                for chunk in chunks where chunk.path != extractedAudioPath {
                    try? FileManager.default.removeItem(atPath: chunk.path)
                }
            } else {
                transcript = try transcribeAudio(
                    audioPath: extractedAudioPath,
                    apiKey: apiKey,
                    provider: .openAi,
                    model: ""
                )
            }
            logger.info("Transcription complete: \(transcript.words.count) words")
        } catch {
            logger.error("Transcription failed: \(error)")
            await AIProcessingTracker.shared.stopProcessing(videoRecordID)
            NotificationService.post(title: "Transcription Failed", body: "\(error)")
            return
        }

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

        // Format paragraphs
        var paragraphedText: String?
        if hasEnoughText {
            do {
                paragraphedText = try formatParagraphs(
                    transcriptText: transcript.fullText,
                    apiKey: apiKey,
                    provider: .openAi
                )
                logger.info("Formatted paragraphs")
            } catch {
                logger.error("Paragraph formatting failed: \(error)")
            }
        }

        // Step 3-5: Only call LLM if transcript has meaningful text
        var generatedTitle: String?
        var generatedSummary: String?
        var generatedChapters: [Chapter] = []

        if hasEnoughText {
            // Steps 3-5: Run title, summary, and chapter generation in parallel
            let fullText = transcript.fullText
            async let titleResult: String? = {
                do {
                    return try generateTitle(transcriptText: fullText, apiKey: apiKey, provider: .openAi)
                } catch {
                    logger.error("Title generation failed: \(error)")
                    return nil
                }
            }()
            async let summaryResult: String? = {
                do {
                    return try generateSummary(transcriptText: fullText, apiKey: apiKey, provider: .openAi)
                } catch {
                    logger.error("Summary generation failed: \(error)")
                    return nil
                }
            }()
            let timestampedText = Self.buildTimestampedTranscript(from: transcript.words)
            async let chaptersResult: [Chapter] = {
                do {
                    return try generateChapters(transcriptText: timestampedText, apiKey: apiKey, provider: .openAi)
                } catch {
                    logger.error("Chapter generation failed: \(error)")
                    return []
                }
            }()

            generatedTitle = await titleResult
            generatedSummary = await summaryResult
            generatedChapters = await chaptersResult

            if let t = generatedTitle { logger.info("Generated title: \(t)") }
            if generatedSummary != nil { logger.info("Generated summary") }
            logger.info("Generated \(generatedChapters.count) chapters")
        } else {
            logger.info("Transcript too short (\(trimmedText.count) chars) — skipping LLM steps")
        }

        // Step 6: Silence detection
        var silentRanges: [TimeRange] = []
        do {
            let defaults = UserDefaults.standard
            let threshDb = defaults.object(forKey: UserDefaultsKeys.silenceThresholdDb) != nil
                ? defaults.double(forKey: UserDefaultsKeys.silenceThresholdDb) : -40.0
            let minDurMs = defaults.object(forKey: UserDefaultsKeys.silenceMinDurationMs) != nil
                ? UInt64(defaults.integer(forKey: UserDefaultsKeys.silenceMinDurationMs)) : 500
            silentRanges = try detectSilence(
                audioPath: extractedAudioPath,
                thresholdDb: Float(threshDb),
                minDurationMs: minDurMs
            )
            logger.info("Found \(silentRanges.count) silent regions")
        } catch {
            logger.error("Silence detection failed: \(error)")
        }

        // Step 7: Persist results to SwiftData
        await TranscriptPersistenceService.persist(
            videoRecordID: videoRecordID,
            transcript: transcript,
            paragraphedText: paragraphedText,
            fillerWords: fillerWords,
            generatedTitle: generatedTitle,
            generatedSummary: generatedSummary,
            generatedChapters: generatedChapters,
            silenceRanges: silentRanges,
            modelContainer: modelContainer
        )

        await AIProcessingTracker.shared.stopProcessing(videoRecordID)
        NotificationService.post(title: "AI Processing Complete", body: "Transcript and summary ready.")
        logger.info("AI pipeline complete for video \(videoRecordID)")
    }

    /// Build a transcript string with periodic timestamps so the LLM can generate accurate chapter markers.
    /// Format: "[M:SS.s] word word word [M:SS.s] word word..."
    /// Uses sub-second precision every ~2s for accurate chapter placement.
    static func buildTimestampedTranscript(from words: [TranscriptWord]) -> String {
        guard !words.isEmpty else { return "" }

        var result = ""
        var lastTimestampMs: Int64 = -2_000 // force first timestamp

        for w in words {
            // Insert a timestamp marker every ~2 seconds for fine-grained chapter accuracy
            if w.startMs - lastTimestampMs >= 2_000 {
                let totalMs = Int(w.startMs)
                let m = totalMs / 60_000
                let s = (totalMs % 60_000) / 1000
                let tenths = (totalMs % 1000) / 100
                if !result.isEmpty { result += "\n" }
                result += String(format: "[%d:%02d.%d] ", m, s, tenths)
                lastTimestampMs = w.startMs
            }
            result += w.word + " "
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Map paragraph breaks in the LLM-formatted text back to word indices.
    /// Returns a set of word indices where a new paragraph begins.
    static func findParagraphStartIndices(originalWords: [String], paragraphedText: String?) -> Set<Int> {
        guard let text = paragraphedText else { return [] }

        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        guard paragraphs.count > 1 else { return [] }

        var indices: Set<Int> = []
        var wordIndex = 0

        for (paraIdx, paragraph) in paragraphs.enumerated() {
            // Count words in this paragraph by splitting on whitespace
            let paraWords = paragraph.split(whereSeparator: \.isWhitespace)
            if paraIdx > 0 {
                indices.insert(wordIndex)
            }
            wordIndex += paraWords.count
        }

        // Only keep indices that are within the original word array bounds
        return indices.filter { $0 < originalWords.count }
    }
}
