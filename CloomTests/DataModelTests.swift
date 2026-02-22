import Testing
import SwiftData
@testable import Cloom

// MARK: - VideoRecord Tests

@Suite("VideoRecord CRUD")
struct VideoRecordTests {
    @Test func createVideoWithDefaults() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: VideoRecord.self, FolderRecord.self, TagRecord.self,
            TranscriptRecord.self, TranscriptWordRecord.self,
            ChapterRecord.self, EditDecisionList.self,
            VideoComment.self, ViewEvent.self,
            configurations: config
        )
        let context = ModelContext(container)

        let video = VideoRecord(
            title: "Test Video",
            filePath: "/tmp/test.mp4",
            durationMs: 120_500,
            fileSizeBytes: 1_000_000
        )
        context.insert(video)
        try context.save()

        let descriptor = FetchDescriptor<VideoRecord>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.title == "Test Video")
        #expect(results.first?.durationMs == 120_500)
        #expect(results.first?.fileSizeBytes == 1_000_000)
        #expect(results.first?.recordingType == "screenOnly")
    }

    @Test func uniqueIDConstraint() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: VideoRecord.self, FolderRecord.self, TagRecord.self,
            TranscriptRecord.self, TranscriptWordRecord.self,
            ChapterRecord.self, EditDecisionList.self,
            VideoComment.self, ViewEvent.self,
            configurations: config
        )
        let context = ModelContext(container)

        let video1 = VideoRecord(title: "A", filePath: "/a.mp4")
        let video2 = VideoRecord(title: "B", filePath: "/b.mp4")
        context.insert(video1)
        context.insert(video2)
        try context.save()

        #expect(video1.id != video2.id)
    }

    @Test func defaultValues() {
        let video = VideoRecord(title: "V", filePath: "/v.mp4")
        #expect(video.thumbnailPath == "")
        #expect(video.durationMs == 0)
        #expect(video.width == 0)
        #expect(video.height == 0)
        #expect(video.fileSizeBytes == 0)
        #expect(video.recordingType == "screenOnly")
        #expect(video.hasTranscript == false)
        #expect(video.webcamFilePath == nil)
        #expect(video.tags.isEmpty)
        #expect(video.chapters.isEmpty)
    }
}

// MARK: - FolderRecord Tests

@Suite("FolderRecord hierarchy")
struct FolderRecordTests {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: FolderRecord.self, VideoRecord.self, TagRecord.self,
            TranscriptRecord.self, TranscriptWordRecord.self,
            ChapterRecord.self, EditDecisionList.self,
            VideoComment.self, ViewEvent.self,
            configurations: config
        )
    }

    @Test func folderHierarchy() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let parent = FolderRecord(name: "Parent")
        let child = FolderRecord(name: "Child")
        child.parent = parent
        context.insert(parent)
        context.insert(child)
        try context.save()

        #expect(child.parent?.name == "Parent")
        #expect(parent.children.count == 1)
        #expect(parent.children.first?.name == "Child")
    }

    @Test func videoCount() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let folder = FolderRecord(name: "My Folder")
        let v1 = VideoRecord(title: "V1", filePath: "/v1.mp4")
        let v2 = VideoRecord(title: "V2", filePath: "/v2.mp4")
        v1.folder = folder
        v2.folder = folder
        context.insert(folder)
        context.insert(v1)
        context.insert(v2)
        try context.save()

        #expect(folder.videoCount == 2)
    }
}

// MARK: - TagRecord Tests

@Suite("TagRecord relationships")
struct TagRecordTests {
    @Test func tagVideoRelationship() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TagRecord.self, VideoRecord.self, FolderRecord.self,
            TranscriptRecord.self, TranscriptWordRecord.self,
            ChapterRecord.self, EditDecisionList.self,
            VideoComment.self, ViewEvent.self,
            configurations: config
        )
        let context = ModelContext(container)

        let tag = TagRecord(name: "Important")
        let video = VideoRecord(title: "V1", filePath: "/v1.mp4")
        tag.videos.append(video)
        context.insert(tag)
        context.insert(video)
        try context.save()

        #expect(tag.videos.count == 1)
        #expect(tag.videos.first?.title == "V1")
    }

    @Test func tagDefaultColor() {
        let tag = TagRecord(name: "Test")
        #expect(tag.color == "#007AFF")
    }
}

// MARK: - EditDecisionList Tests

@Suite("EditDecisionList")
struct EditDecisionListTests {
    @Test func defaultHasNoEdits() {
        let edl = EditDecisionList(videoID: "test-123")
        #expect(edl.hasEdits == false)
        #expect(edl.cuts.isEmpty)
        #expect(edl.stitchVideoIDs.isEmpty)
        #expect(edl.speedMultiplier == 1.0)
        #expect(edl.thumbnailTimeMs == 500)
        #expect(edl.trimStartMs == 0)
        #expect(edl.trimEndMs == 0)
    }

    @Test func cutsRoundTrip() {
        let edl = EditDecisionList(videoID: "test-123")
        edl.cuts = [
            CutRange(startMs: 1000, endMs: 3000),
            CutRange(startMs: 5000, endMs: 7000)
        ]

        #expect(edl.cuts.count == 2)
        #expect(edl.cuts.first?.startMs == 1000)
        #expect(edl.cuts.first?.endMs == 3000)
        #expect(edl.hasEdits == true)
    }

    @Test func stitchVideoIDsRoundTrip() {
        let edl = EditDecisionList(videoID: "test-123")
        edl.stitchVideoIDs = ["abc-123", "def-456"]

        #expect(edl.stitchVideoIDs.count == 2)
        #expect(edl.stitchVideoIDs == ["abc-123", "def-456"])
        #expect(edl.hasEdits == true)
    }

    @Test func hasEditsWhenTrimStartNonZero() {
        let edl = EditDecisionList(videoID: "v1", trimStartMs: 500)
        #expect(edl.hasEdits == true)
    }

    @Test func hasEditsWhenTrimEndNonZero() {
        let edl = EditDecisionList(videoID: "v1", trimEndMs: 10_000)
        #expect(edl.hasEdits == true)
    }

    @Test func hasEditsWhenSpeedChanged() {
        let edl = EditDecisionList(videoID: "v1")
        edl.speedMultiplier = 2.0
        #expect(edl.hasEdits == true)
    }

    @Test func hasEditsWhenThumbnailTimeMoved() {
        let edl = EditDecisionList(videoID: "v1")
        edl.thumbnailTimeMs = 1000
        #expect(edl.hasEdits == true)
    }

    @Test func cutRangeEquality() {
        let a = CutRange(id: "same", startMs: 100, endMs: 200)
        let b = CutRange(id: "same", startMs: 100, endMs: 200)
        #expect(a == b)
    }
}

// MARK: - TranscriptRecord Tests

@Suite("TranscriptRecord")
struct TranscriptRecordTests {
    @Test func transcriptWithWords() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TranscriptRecord.self, TranscriptWordRecord.self,
            VideoRecord.self, FolderRecord.self, TagRecord.self,
            ChapterRecord.self, EditDecisionList.self,
            VideoComment.self, ViewEvent.self,
            configurations: config
        )
        let context = ModelContext(container)

        let transcript = TranscriptRecord(videoID: "v1", fullText: "Hello world")
        let word1 = TranscriptWordRecord(word: "Hello", startMs: 0, endMs: 500)
        let word2 = TranscriptWordRecord(word: "world", startMs: 500, endMs: 1000)
        word1.transcript = transcript
        word2.transcript = transcript
        context.insert(transcript)
        context.insert(word1)
        context.insert(word2)
        try context.save()

        #expect(transcript.fullText == "Hello world")
        #expect(transcript.words.count == 2)
        #expect(transcript.language == "en")
    }

    @Test func wordDefaults() {
        let word = TranscriptWordRecord(word: "test", startMs: 0, endMs: 100)
        #expect(word.confidence == 1.0)
        #expect(word.isFillerWord == false)
    }
}

// MARK: - ChapterRecord Tests

@Suite("ChapterRecord")
struct ChapterRecordTests {
    @Test func chapterProperties() {
        let chapter = ChapterRecord(title: "Intro", startMs: 0)
        #expect(chapter.title == "Intro")
        #expect(chapter.startMs == 0)
        #expect(!chapter.id.isEmpty)
    }
}
