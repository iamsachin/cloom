import AVFoundation
import CoreMedia
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ExportWriter+Subtitles")

extension ExportWriter {

    /// Create AVAssetWriterInput for tx3g (3GPP Timed Text) subtitles.
    static func createSubtitleWriterInput() -> AVAssetWriterInput {
        let input: AVAssetWriterInput
        if let fd = makeTx3gFormatDescription() {
            input = AVAssetWriterInput(mediaType: .subtitle, outputSettings: nil, sourceFormatHint: fd)
        } else {
            logger.warning("Could not create tx3g format description, subtitle track may not work in all players")
            input = AVAssetWriterInput(mediaType: .subtitle, outputSettings: nil)
        }
        input.expectsMediaDataInRealTime = false
        return input
    }

    /// Write tx3g subtitle samples for each phrase.
    static func writeSubtitleSamples(
        to writerInput: AVAssetWriterInput,
        phrases: [SubtitlePhrase],
        progress: @escaping @Sendable (Double) -> Void
    ) async {
        guard !phrases.isEmpty else {
            writerInput.markAsFinished()
            return
        }

        guard let fd = makeTx3gFormatDescription() else {
            logger.error("Failed to create tx3g format description for subtitle writing")
            writerInput.markAsFinished()
            return
        }

        nonisolated(unsafe) let input = writerInput

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let queue = DispatchQueue(label: "com.cloom.export.subtitle")
            var phraseIndex = 0

            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData {
                    guard phraseIndex < phrases.count else {
                        input.markAsFinished()
                        continuation.resume()
                        return
                    }

                    let phrase = phrases[phraseIndex]
                    if let sb = buildTx3gSampleBuffer(phrase: phrase, formatDescription: fd) {
                        input.append(sb)
                    }

                    phraseIndex += 1
                    progress(Double(phraseIndex) / Double(phrases.count))
                }
            }
        }
    }

    // MARK: - tx3g Helpers

    /// Shared tx3g format description builder (eliminates duplication).
    static func makeTx3gFormatDescription() -> CMFormatDescription? {
        let tx3gInitData = Data([
            0x00, 0x00, 0x00, 0x00, // displayFlags
            0x00,                     // horizontal-justification (left)
            0x01,                     // vertical-justification (bottom)
            0x00, 0x00, 0x00, 0x00,  // background-color-rgba
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // default-text-box
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // style-record (start)
            0x00, 0x00,             // startChar, endChar
            0x00, 0x01,             // font-ID
            0x00,                    // face-style-flags
            0x12,                    // font-size (18pt)
            0xFF, 0xFF, 0xFF, 0xFF, // text-color-rgba (white)
        ])

        var formatDescription: CMFormatDescription?

        tx3gInitData.withUnsafeBytes { rawBuffer in
            let ptr = rawBuffer.baseAddress!
            let extensions = [
                "mdia" as CFString: [
                    "minf" as CFString: [
                        "stbl" as CFString: [
                            "stsd" as CFString: [
                                "tx3g" as CFString: NSData(bytes: ptr, length: tx3gInitData.count),
                            ] as CFDictionary,
                        ] as CFDictionary,
                    ] as CFDictionary,
                ] as CFDictionary,
            ] as CFDictionary

            CMFormatDescriptionCreate(
                allocator: kCFAllocatorDefault,
                mediaType: kCMMediaType_Subtitle,
                mediaSubType: FourCharCode(0x74783367), // 'tx3g'
                extensions: extensions,
                formatDescriptionOut: &formatDescription
            )
        }

        return formatDescription
    }

    private static func buildTx3gSampleBuffer(
        phrase: SubtitlePhrase,
        formatDescription: CMFormatDescription
    ) -> CMSampleBuffer? {
        let pts = CMTime(value: CMTimeValue(phrase.startMs), timescale: 1000)
        let dur = CMTime(value: CMTimeValue(phrase.endMs - phrase.startMs), timescale: 1000)

        let textData = Data(phrase.text.utf8)
        var payload = Data()
        var bigEndianLen = UInt16(textData.count).bigEndian
        payload.append(Data(bytes: &bigEndianLen, count: 2))
        payload.append(textData)

        var blockBuffer: CMBlockBuffer?
        let dataLen = payload.count

        payload.withUnsafeBytes { rawBuf in
            let bufPtr = rawBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
            CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: nil,
                blockLength: dataLen,
                blockAllocator: kCFAllocatorDefault,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: dataLen,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
            if let block = blockBuffer {
                CMBlockBufferReplaceDataBytes(
                    with: bufPtr,
                    blockBuffer: block,
                    offsetIntoDestination: 0,
                    dataLength: dataLen
                )
            }
        }

        guard let block = blockBuffer else { return nil }

        var timingInfo = CMSampleTimingInfo(
            duration: dur,
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid
        )
        var sampleSize = dataLen
        var sampleBuffer: CMSampleBuffer?

        CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: block,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )

        return sampleBuffer
    }
}
