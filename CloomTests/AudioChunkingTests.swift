import Testing
@testable import Cloom

// MARK: - Task 167: Audio Chunking Tests

@Suite("Audio Chunk Calculations")
struct AudioChunkingTests {

    // MARK: - calculateChunkCount

    @Test func fileSmallerThanMax() {
        #expect(calculateChunkCount(fileSize: 10_000_000, maxChunkBytes: 20_000_000) == 1)
    }

    @Test func fileEqualToMax() {
        #expect(calculateChunkCount(fileSize: 20_000_000, maxChunkBytes: 20_000_000) == 1)
    }

    @Test func fileDoubleMax() {
        #expect(calculateChunkCount(fileSize: 40_000_000, maxChunkBytes: 20_000_000) == 2)
    }

    @Test func fileSlightlyOverMax() {
        // 25MB / 20MB → ceil(1.25) = 2
        #expect(calculateChunkCount(fileSize: 25_000_000, maxChunkBytes: 20_000_000) == 2)
    }

    @Test func fileTripleMax() {
        #expect(calculateChunkCount(fileSize: 60_000_000, maxChunkBytes: 20_000_000) == 3)
    }

    @Test func zeroFileSize() {
        #expect(calculateChunkCount(fileSize: 0, maxChunkBytes: 20_000_000) == 1)
    }

    @Test func zeroMaxBytes() {
        // Guard: maxChunkBytes <= 0 → return 1
        #expect(calculateChunkCount(fileSize: 100, maxChunkBytes: 0) == 1)
    }

    // MARK: - calculateChunkDuration

    @Test func singleChunk() {
        let duration = calculateChunkDuration(totalSeconds: 120.0, chunkCount: 1)
        #expect(duration == 120.0)
    }

    @Test func twoChunks() {
        let duration = calculateChunkDuration(totalSeconds: 120.0, chunkCount: 2)
        #expect(duration == 60.0)
    }

    @Test func threeChunks() {
        let duration = calculateChunkDuration(totalSeconds: 90.0, chunkCount: 3)
        #expect(duration == 30.0)
    }

    @Test func zeroChunkCount() {
        // Guard: chunkCount <= 0 → return totalSeconds
        let duration = calculateChunkDuration(totalSeconds: 120.0, chunkCount: 0)
        #expect(duration == 120.0)
    }

    @Test func unevenDivision() {
        let duration = calculateChunkDuration(totalSeconds: 100.0, chunkCount: 3)
        #expect(abs(duration - 33.333333) < 0.001)
    }
}
