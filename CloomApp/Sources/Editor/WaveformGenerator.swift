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

    func generatePeaks(from url: URL, peakCount: Int) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        guard let audioTrack = audioTracks.first else {
            logger.info("No audio track — returning empty waveform")
            return Array(repeating: 0, count: peakCount)
        }

        let reader = try AVAssetReader(asset: asset)

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        reader.add(output)

        guard reader.startReading() else {
            throw WaveformError.readerFailed(reader.error?.localizedDescription ?? "Unknown")
        }

        // Collect all samples
        var allSamples: [Int16] = []
        while let buffer = output.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let length = CMBlockBufferGetDataLength(blockBuffer)
            var data = Data(count: length)
            _ = data.withUnsafeMutableBytes { ptr in
                guard let baseAddress = ptr.baseAddress else { return noErr }
                return CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: baseAddress)
            }
            let samples = data.withUnsafeBytes { raw in
                Array(raw.bindMemory(to: Int16.self))
            }
            allSamples.append(contentsOf: samples)
        }

        guard !allSamples.isEmpty else {
            return Array(repeating: 0, count: peakCount)
        }

        // Downsample to peakCount peaks
        let samplesPerPeak = max(1, allSamples.count / peakCount)
        var peaks: [Float] = []
        peaks.reserveCapacity(peakCount)

        for i in 0..<peakCount {
            let start = i * samplesPerPeak
            let end = min(start + samplesPerPeak, allSamples.count)
            guard start < end else {
                peaks.append(0)
                continue
            }
            var maxVal: Int16 = 0
            for j in start..<end {
                let absVal = abs(allSamples[j])
                if absVal > maxVal { maxVal = absVal }
            }
            peaks.append(Float(maxVal) / Float(Int16.max))
        }

        logger.info("Generated \(peaks.count) waveform peaks from \(allSamples.count) samples")
        return peaks
    }
}
