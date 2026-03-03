import AVFoundation
import CoreMedia
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ExportWriter+Subtitles")

extension ExportWriter {

    /// Build a complete list of subtitle samples with empty gap-fillers so the
    /// subtitle track spans the full video duration.
    static func buildSamplesWithGaps(
        phrases: [SubtitlePhrase],
        durationMs: Int64
    ) -> [SubtitlePhrase] {
        var samples: [SubtitlePhrase] = []
        var cursor: Int64 = 0

        for phrase in phrases {
            // Fill gap before this phrase with an empty sample
            if phrase.startMs > cursor {
                samples.append(SubtitlePhrase(text: "", startMs: cursor, endMs: phrase.startMs))
            }
            samples.append(phrase)
            cursor = phrase.endMs
        }

        // Trailing empty sample to cover remainder of video
        if cursor < durationMs {
            samples.append(SubtitlePhrase(text: "", startMs: cursor, endMs: durationMs))
        }

        return samples
    }

    // MARK: - tx3g Helpers

    /// Create tx3g format description using Apple's named extension keys.
    static func makeTx3gFormatDescription() -> CMFormatDescription? {
        let extensions: [CFString: Any] = [
            kCMTextFormatDescriptionExtension_DisplayFlags: 0 as CFNumber,
            kCMTextFormatDescriptionExtension_HorizontalJustification: 0 as CFNumber,
            kCMTextFormatDescriptionExtension_VerticalJustification: 1 as CFNumber,
            kCMTextFormatDescriptionExtension_BackgroundColor: [
                kCMTextFormatDescriptionColor_Red: 0 as CFNumber,
                kCMTextFormatDescriptionColor_Green: 0 as CFNumber,
                kCMTextFormatDescriptionColor_Blue: 0 as CFNumber,
                kCMTextFormatDescriptionColor_Alpha: 0 as CFNumber,
            ] as CFDictionary,
            kCMTextFormatDescriptionExtension_DefaultTextBox: [
                kCMTextFormatDescriptionRect_Top: 0 as CFNumber,
                kCMTextFormatDescriptionRect_Left: 0 as CFNumber,
                kCMTextFormatDescriptionRect_Bottom: 0 as CFNumber,
                kCMTextFormatDescriptionRect_Right: 0 as CFNumber,
            ] as CFDictionary,
            kCMTextFormatDescriptionExtension_DefaultStyle: [
                kCMTextFormatDescriptionStyle_StartChar: 0 as CFNumber,
                kCMTextFormatDescriptionStyle_EndChar: 0 as CFNumber,
                kCMTextFormatDescriptionStyle_Font: 1 as CFNumber,
                kCMTextFormatDescriptionStyle_FontFace: 0 as CFNumber,
                kCMTextFormatDescriptionStyle_FontSize: 18 as CFNumber,
                kCMTextFormatDescriptionStyle_ForegroundColor: [
                    kCMTextFormatDescriptionColor_Red: 255 as CFNumber,
                    kCMTextFormatDescriptionColor_Green: 255 as CFNumber,
                    kCMTextFormatDescriptionColor_Blue: 255 as CFNumber,
                    kCMTextFormatDescriptionColor_Alpha: 255 as CFNumber,
                ] as CFDictionary,
            ] as CFDictionary,
            kCMTextFormatDescriptionExtension_FontTable: [
                "1" as CFString: "Sans-Serif" as CFString,
            ] as CFDictionary,
        ]

        var formatDescription: CMFormatDescription?
        CMFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            mediaType: kCMMediaType_Subtitle,
            mediaSubType: kCMTextFormatType_3GText,
            extensions: extensions as CFDictionary,
            formatDescriptionOut: &formatDescription
        )
        return formatDescription
    }

    static func buildTx3gSampleBuffer(
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
