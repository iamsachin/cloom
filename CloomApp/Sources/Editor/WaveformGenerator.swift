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
            let trackPeaks = try readTrackPeaks(asset: asset, track: audioTrack, peakCount: peakCount, micSensitivity: micSensitivity)
            for i in 0..<peakCount {
                combinedPeaks[i] = max(combinedPeaks[i], trackPeaks[i])
            }
        }

        let totalEnergy = combinedPeaks.reduce(0, +)
        logger.info("Generated \(combinedPeaks.count) waveform peaks from \(audioTracks.count) audio tracks (energy: \(totalEnergy))")
        return combinedPeaks
    }

    private func readTrackPeaks(asset: AVURLAsset, track: AVAssetTrack, peakCount: Int, micSensitivity: Int) throws -> [Float] {
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

        // Streaming peak calculation — O(peakCount) memory instead of O(total_samples).
        // First pass: count total samples to compute samplesPerPeak.
        var totalSamples = 0
        var buffers: [(CMBlockBuffer, Int)] = []

        while let buffer = output.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let length = CMBlockBufferGetDataLength(blockBuffer)
            let sampleCount = length / MemoryLayout<Int16>.size
            totalSamples += sampleCount
            buffers.append((blockBuffer, length))
        }

        guard totalSamples > 0 else {
            return [Float](repeating: 0, count: peakCount)
        }

        let samplesPerPeak = max(1, totalSamples / peakCount)
        var peaks = [Float](repeating: 0, count: peakCount)
        var globalSampleIndex = 0

        for (blockBuffer, length) in buffers {
            var data = Data(count: length)
            _ = data.withUnsafeMutableBytes { ptr in
                guard let baseAddress = ptr.baseAddress else { return noErr }
                return CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: baseAddress)
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
