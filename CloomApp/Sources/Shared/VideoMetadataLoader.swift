import AVFoundation

struct VideoMetadata: Sendable {
    let videoBitrate: Int?
    let videoCodec: String?
    let fps: Double?
    let audioTrackCount: Int
    let audioCodec: String?
}

enum VideoMetadataLoader {

    static func load(from filePath: String) async -> VideoMetadata {
        let asset = AVURLAsset(url: URL(fileURLWithPath: filePath))

        var videoBitrate: Int?
        var videoCodec: String?
        var fps: Double?
        var audioTrackCount = 0
        var audioCodec: String?

        do {
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            if let videoTrack = videoTracks.first {
                let estimatedRate = try await videoTrack.load(.estimatedDataRate)
                videoBitrate = Int(estimatedRate)

                let nominalFPS = try await videoTrack.load(.nominalFrameRate)
                fps = Double(nominalFPS)

                let descriptions = try await videoTrack.load(.formatDescriptions)
                if let desc = descriptions.first {
                    let codecType = CMFormatDescriptionGetMediaSubType(desc)
                    videoCodec = codecName(from: codecType)
                }
            }

            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            audioTrackCount = audioTracks.count
            if let audioTrack = audioTracks.first {
                let descriptions = try await audioTrack.load(.formatDescriptions)
                if let desc = descriptions.first {
                    let codecType = CMFormatDescriptionGetMediaSubType(desc)
                    audioCodec = codecName(from: codecType)
                }
            }
        } catch {
            // Return partial metadata on failure
        }

        return VideoMetadata(
            videoBitrate: videoBitrate,
            videoCodec: videoCodec,
            fps: fps,
            audioTrackCount: audioTrackCount,
            audioCodec: audioCodec
        )
    }

    private static func codecName(from fourCC: FourCharCode) -> String {
        return switch fourCC {
        case kCMVideoCodecType_HEVC: "HEVC (H.265)"
        case kCMVideoCodecType_H264: "H.264"
        case kCMVideoCodecType_VP9: "VP9"
        case kCMVideoCodecType_AV1: "AV1"
        case kAudioFormatMPEG4AAC: "AAC"
        case kAudioFormatOpus: "Opus"
        case kAudioFormatLinearPCM: "PCM"
        case kAudioFormatAppleLossless: "ALAC"
        default: fourCharString(fourCC)
        }
    }

    private static func fourCharString(_ code: FourCharCode) -> String {
        let chars = [
            Character(UnicodeScalar((code >> 24) & 0xFF)!),
            Character(UnicodeScalar((code >> 16) & 0xFF)!),
            Character(UnicodeScalar((code >> 8) & 0xFF)!),
            Character(UnicodeScalar(code & 0xFF)!),
        ]
        return String(chars).trimmingCharacters(in: .whitespaces)
    }
}
