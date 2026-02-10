# Testing Strategy

## Swift Testing (Swift Testing framework — `@Test`, `#expect`)

Every service has a protocol → mocked in tests.

| Module | Test Type | What to Test |
|--------|-----------|-------------|
| Shared/ | Unit | Codable round-trips, computed properties, equality |
| Capture/ | Unit + Integration | Mock `ScreenCaptureService` via protocol; Integration: enumerate displays |
| Camera/ | Unit + Integration | Mock camera service; Integration: camera frame delivery |
| Recording/ | **Unit (primary)** | Exhaustive state machine transitions (every valid + invalid). Timer accuracy. Pause/resume timestamps. |
| Compositing/ | Unit + Integration | Mock CompositingService; Integration: compose test video + webcam overlay, verify output |
| Export/ | Unit + Integration | Mock ExportService; Integration: apply EDL to test video, verify duration/cuts |
| Overlay/ | Unit + UI | Drawing stroke geometry, undo/redo stack, bubble position calculations |
| Editor/ | Unit | EditDecisionList construction, time range math, overlap detection |
| Player/ | Unit | Caption parsing (SRT/VTT), chapter navigation, transcript sync |
| Data/ | Integration | SwiftData CRUD with in-memory ModelContainer. Schema migration tests. |
| Library/ | Integration | Save video via SwiftData, query with @Query, verify data. Search/filter. |
| Settings/ | Unit | Preference read/write via PreferencesManager, default values |
| AI/ | Unit | Mock AI bridge, verify orchestration sequencing |
| Bridge/ | Integration | FFI round-trips for every exported Rust function |

### Mocking Pattern

```swift
protocol ScreenCaptureService {
    func availableContent() async throws -> CaptureContent
    func startCapture(config: CaptureConfiguration) async throws -> CaptureStream
    func stopCapture() async throws -> URL
}

// In tests:
class MockScreenCaptureService: ScreenCaptureService {
    var availableContentResult: Result<CaptureContent, Error> = .success(.mock)
    func availableContent() async throws -> CaptureContent {
        try availableContentResult.get()
    }
}
```

### SwiftData Testing Pattern

```swift
@Test func testSaveAndFetchVideo() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: VideoRecord.self, configurations: config)
    let context = container.mainContext

    let video = VideoRecord(id: UUID().uuidString, title: "Test", ...)
    context.insert(video)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<VideoRecord>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.title == "Test")
}
```

---

## Rust Testing (`cargo test` + `rstest` + `mockall`)

| Module | Test Type | What to Test |
|--------|-----------|-------------|
| audio/ | Unit + Integration | Silence detection on synthetic audio files. Filler word identification. Audio level calculation. Test with WAV + AAC formats via symphonia. |
| ai/ | Unit + Integration | Mock HTTP responses (wiremock or manual). JSON parsing. Retry logic. Error handling. Rate limiting. Provider/model switching behavior. |
| export/ | Unit + Integration | GIF generation from known frame data. Color quantization. Frame differencing. Output file validity. |

### Test Fixtures

`cloom-core/tests/fixtures/` will contain:
- Sample audio files (silence, speech — WAV and AAC formats)
- Mock API responses (transcription JSON for `gpt-4o-mini-transcribe`, OpenAI LLM JSON; provider/model abstraction fixtures optional)

---

## Integration / E2E Tests

- **Recording round-trip:** Record screen 5s → stop → verify MP4 exists and plays
- **Compositing round-trip:** Record screen + webcam → composite → verify single MP4 with overlay
- **Edit round-trip:** Record → trim → export → verify duration matches expected
- **AI round-trip:** Record → transcribe (mock API) → verify transcript stored in SwiftData
- **Library round-trip:** Record → save → search → find → delete
- **GIF round-trip:** Record → export GIF via Rust → verify GIF file is valid and optimized

---

## UI Testing

- SwiftUI Previews extensively during development
- Xcode UI tests (`XCUIApplication`) for critical flows
- Optional: snapshot tests via `swift-snapshot-testing`

---

## Verification Plan

1. **Phase 1A verification:** `build.sh` compiles Rust + Swift. App launches in menu bar. Rust FFI returns a value. SwiftData container initializes.
2. **Phase 1B verification:** Record → stop → MP4 saved to `~/Movies/Cloom/`. Library shows video. Click plays it.
3. **Per-module:** Tests written BEFORE implementation (TDD). `swift test` + `cargo test`.
4. **Per-phase:** Manual end-to-end test of complete flow.
5. **Permissions:** Test on clean user account to verify TCC flow.
