import AVFoundation
import CoreMedia

/// Applies a linear gain multiplier to microphone audio samples.
/// 0.0 = muted, 1.0 = unity (unchanged).
final class MicGainProcessor: @unchecked Sendable {
    private let gainLinear: Float

    init(sensitivity: Int) {
        // sensitivity 0–200 maps to gain 0.0–2.0 (100% = unity)
        self.gainLinear = max(0, min(2, Float(sensitivity) / 100.0))
    }

    /// Returns true if gain is effectively unity (no processing needed).
    var isUnity: Bool { abs(gainLinear - 1.0) < 0.001 }

    func process(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
        if isUnity { return sampleBuffer }

        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return sampleBuffer
        }

        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
        guard let asbd else { return sampleBuffer }

        // Only handle float32 PCM (SCStream's typical format)
        guard asbd.pointee.mFormatID == kAudioFormatLinearPCM,
              asbd.pointee.mBitsPerChannel == 32,
              (asbd.pointee.mFormatFlags & kAudioFormatFlagIsFloat) != 0 else {
            return sampleBuffer
        }

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

        let buffers = UnsafeMutableAudioBufferListPointer(&audioBufferList)
        for buf in buffers {
            guard let data = buf.mData else { continue }
            let frameCount = Int(buf.mDataByteSize) / MemoryLayout<Float>.size
            let samples = data.bindMemory(to: Float.self, capacity: frameCount)

            if gainLinear == 0 {
                memset(data, 0, Int(buf.mDataByteSize))
            } else {
                for i in 0..<frameCount {
                    samples[i] = max(-1.0, min(1.0, samples[i] * gainLinear))
                }
            }
        }

        // Create new CMSampleBuffer with modified data
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
