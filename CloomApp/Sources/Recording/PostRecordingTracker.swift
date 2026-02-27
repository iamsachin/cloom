import Foundation

enum PostRecordingStep: String {
    case finalizing = "Finalizing recording..."
    case mixingAudio = "Mixing audio..."
    case stitchingSegments = "Stitching segments..."
    case extractingMetadata = "Extracting metadata..."
    case generatingThumbnail = "Generating thumbnail..."
    case saving = "Saving to library..."
}

struct PostRecordingInfo {
    let id: String
    let title: String
    let startedAt: Date
    var step: PostRecordingStep
}

@MainActor
@Observable
final class PostRecordingTracker {
    static let shared = PostRecordingTracker()

    private(set) var activeRecording: PostRecordingInfo?

    var isProcessing: Bool { activeRecording != nil }

    func start(title: String) {
        activeRecording = PostRecordingInfo(
            id: UUID().uuidString,
            title: title,
            startedAt: Date(),
            step: .finalizing
        )
    }

    func updateStep(_ step: PostRecordingStep) {
        activeRecording?.step = step
    }

    func finish() {
        activeRecording = nil
    }
}
