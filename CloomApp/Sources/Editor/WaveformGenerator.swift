import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "WaveformGenerator")

actor WaveformGenerator {
    enum WaveformError: LocalizedError {
        case noAudioTrack
        case readerFailed(String)

        var errorDescription: String? {
            switch self {
            case .noAudioTrack: "No audio track found"
            case .readerFailed(let msg): "Audio reader failed: \(msg)"
            }
        }
    }

    func generatePeaks(from url: URL, peakCount: Int, micSensitivity: Int = 100) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        guard !audioTracks.isEmpty else {
            logger.info("No audio track — returning empty waveform")
            return Array(repeating: 0, count: peakCount)
        }

        // Read samples from all audio tracks and combine them.
        // VideoWriter creates system audio (track 0) and mic audio (track 1).
        // If system audio is silent, we still get the mic waveform this way.
        var combinedPeaks = [Float](repeating: 0, count: peakCount)

        for audioTrack in audioTracks {
            let trackPeaks = try await readTrackPeaks(asset: asset, track: audioTrack, peakCount: peakCount, micSensitivity: micSensitivity)
            for i in 0..<peakCount {
                combinedPeaks[i] = max(combinedPeaks[i], trackPeaks[i])
            }
        }

        let totalEnergy = combinedPeaks.reduce(0, +)
        logger.info("Generated \(combinedPeaks.count) waveform peaks from \(audioTracks.count) audio tracks (energy: \(totalEnergy))")
        return combinedPeaks
    }

    private func readTrackPeaks(asset: AVURLAsset, track: AVAssetTrack, peakCount: Int, micSensitivity: Int) async throws -> [Float] {
        let reader = try AVAssetReader(asset: asset)

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(output)

        guard reader.startReading() else {
            logger.warning("Failed to read audio track: \(reader.error?.localizedDescription ?? "Unknown")")
            return [Float](repeating: 0, count: peakCount)
        }

        // Estimate total samples from track duration to avoid accumulating all buffers.
        // PCM output is 16-bit, so default to 48kHz stereo (2 channels) as a reasonable estimate.
        let duration = try await asset.load(.duration)
        let durationSec = CMTimeGetSeconds(duration)
        let sampleRate: Double = 48000
        let channels: Double = 2
        let estimatedSamples = Int(durationSec * sampleRate * channels)
        let samplesPerPeak = max(1, estimatedSamples / peakCount)

        // Single-pass streaming: process each buffer immediately, O(peakCount) memory
        var peaks = [Float](repeating: 0, count: peakCount)
        var globalSampleIndex = 0

        while let buffer = output.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let length = CMBlockBufferGetDataLength(blockBuffer)

            // Try zero-copy access first, fall back to CMBlockBufferCopyDataBytes
            var dataPointer: UnsafeMutablePointer<Int8>?
            var lengthAtOffset: Int = 0
            let status = CMBlockBufferGetDataPointer(
                blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset,
                totalLengthOut: nil, dataPointerOut: &dataPointer
            )

            if status == noErr, let ptr = dataPointer, lengthAtOffset == length {
                // Zero-copy path — contiguous block
                let sampleCount = length / MemoryLayout<Int16>.size
                ptr.withMemoryRebound(to: Int16.self, capacity: sampleCount) { samples in
                    for i in 0..<sampleCount {
                        let binIndex = min(globalSampleIndex / samplesPerPeak, peakCount - 1)
                        let absVal = Float(abs(samples[i])) / Float(Int16.max)
                        if absVal > peaks[binIndex] {
                            peaks[binIndex] = absVal
                        }
                        globalSampleIndex += 1
                    }
                }
            } else {
                // Fallback: copy bytes for non-contiguous blocks
                var data = Data(count: length)
                data.withUnsafeMutableBytes { dest in
                    guard let baseAddress = dest.baseAddress else { return }
                    CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: baseAddress)
                }
                data.withUnsafeBytes { raw in
                    let samples = raw.bindMemory(to: Int16.self)
                    for sample in samples {
                        let binIndex = min(globalSampleIndex / samplesPerPeak, peakCount - 1)
                        let absVal = Float(abs(sample)) / Float(Int16.max)
                        if absVal > peaks[binIndex] {
                            peaks[binIndex] = absVal
                        }
                        globalSampleIndex += 1
                    }
                }
            }
        }

        guard globalSampleIndex > 0 else {
            return [Float](repeating: 0, count: peakCount)
        }

        // Adaptive noise floor: use the median peak as the background noise level,
        // then zero out anything below a threshold to suppress fan/hum while keeping speech.
        let sensitivityFraction = max(0, min(1, Float(min(micSensitivity, 100)) / 100.0))
        let noiseMultiplier: Float = 5.0 - sensitivityFraction * 3.0 // 5x at 0%, 2x at 100%+
        let sorted = peaks.sorted()
        let median = sorted[sorted.count / 2]
        let noiseFloor = median * noiseMultiplier
        return peaks.map { $0 < noiseFloor ? 0 : $0 }
    }
}
