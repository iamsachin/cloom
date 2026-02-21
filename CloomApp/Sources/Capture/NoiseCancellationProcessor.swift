import AVFoundation
import CoreMedia
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "NoiseCancellation")

/// Simple noise gate processor that zeroes out audio samples below a threshold.
/// V1 approach: scan RMS amplitude of CMSampleBuffer, zero out frames below -40 dB.
final class NoiseCancellationProcessor: @unchecked Sendable {
    private let thresholdDb: Float
    private let thresholdLinear: Float

    init(thresholdDb: Float = -40.0) {
        self.thresholdDb = thresholdDb
        self.thresholdLinear = powf(10.0, thresholdDb / 20.0)
    }

    /// Process a microphone CMSampleBuffer through the noise gate.
    /// Returns a new CMSampleBuffer with gated audio data (original buffers from SCStream may be immutable).
    func process(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return sampleBuffer
        }

        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
        guard let asbd else { return sampleBuffer }

        // Only handle float32 PCM (which is what SCStream typically provides)
        guard asbd.pointee.mFormatID == kAudioFormatLinearPCM,
              asbd.pointee.mBitsPerChannel == 32,
              (asbd.pointee.mFormatFlags & kAudioFormatFlagIsFloat) != 0 else {
            return sampleBuffer
        }

        // Get audio buffer list
        var blockBuffer: CMBlockBuffer?
        var audioBufferList = AudioBufferList()
        var bufferListSize = 0

        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &bufferListSize,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: nil
        )

        guard status == noErr else { return sampleBuffer }

        let result = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )

        guard result == noErr else { return sampleBuffer }

        // Process each audio buffer
        let buffers = UnsafeMutableAudioBufferListPointer(&audioBufferList)
        for buf in buffers {
            guard let data = buf.mData else { continue }
            let frameCount = Int(buf.mDataByteSize) / MemoryLayout<Float>.size
            let samples = data.bindMemory(to: Float.self, capacity: frameCount)

            // Calculate RMS for this buffer
            var sumSquares: Float = 0
            for i in 0..<frameCount {
                sumSquares += samples[i] * samples[i]
            }
            let rms = sqrtf(sumSquares / max(Float(frameCount), 1))

            // If RMS is below threshold, zero out all samples (noise gate)
            if rms < thresholdLinear {
                memset(data, 0, Int(buf.mDataByteSize))
            }
        }

        // Create a new CMSampleBuffer with the modified data
        // Since we modified the block buffer in-place via the audio buffer list,
        // we need to create a new sample buffer pointing to this data
        guard let newBlockBuffer = blockBuffer else { return sampleBuffer }

        var newSampleBuffer: CMSampleBuffer?
        let timing = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)
        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)

        var sampleTiming = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: timing,
            decodeTimeStamp: .invalid
        )

        let createStatus = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: newBlockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDesc,
            sampleCount: numSamples,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &sampleTiming,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &newSampleBuffer
        )

        if createStatus == noErr, let buffer = newSampleBuffer {
            return buffer
        }

        return sampleBuffer
    }
}
