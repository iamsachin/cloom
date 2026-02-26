# Testing Strategy

## Swift Testing (Swift Testing framework)

Services are concrete classes (not protocol-based). Testing uses in-memory SwiftData containers and direct assertions via `@Test` and `#expect`.

### Unit Tests (CloomTests/ — 32 tests in 2 files)

| File | Test Count | What's Tested |
|------|-----------|---------------|
| DataModelTests.swift | ~25 | VideoRecord CRUD/defaults/unique ID, FolderRecord hierarchy/videoCount, TagRecord relationship/color, EditDecisionList defaults/cuts/stitch/hasEdits, TranscriptRecord words/defaults, ChapterRecord properties, BookmarkRecord properties/note/relationship/cascade/CRUD |
| RecordingSettingsTests.swift | ~7 | VideoQuality bitrates/labels/identifiable/allCases, RecordingSettings defaults/custom/invalid raw value |

### Why No UI Tests

Cloom is a screen recording app that depends on TCC-protected hardware (Screen Recording, Camera, Microphone). UI tests cannot:
- Grant TCC permissions programmatically (macOS security restriction)
- Record or capture anything without pre-granted permissions
- Reliably interact with MenuBarExtra apps (XCUIApplication doesn't find menu bar items)

Even skipping the onboarding screen, UI tests would only verify that views appear — they can't test that recording, compositing, or export actually work. The core functionality requires manual testing or a CI Mac with MDM-provisioned TCC profiles.

**Higher-ROI alternatives for future coverage:**
- Unit-testing the compositor/writer pipeline with synthetic `CMSampleBuffer`s
- Snapshot tests for view rendering with mock data
- Integration tests for SwiftData query/filter logic

### SwiftData Testing Pattern

```swift
@Test func createVideoWithDefaults() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: VideoRecord.self, FolderRecord.self, TagRecord.self,
        TranscriptRecord.self, TranscriptWordRecord.self, ChapterRecord.self,
        BookmarkRecord.self, EditDecisionList.self,
        VideoComment.self, ViewEvent.self,
        configurations: config
    )
    let context = ModelContext(container)

    let video = VideoRecord(title: "Test", filePath: "/test.mp4")
    context.insert(video)
    try context.save()

    let results = try context.fetch(FetchDescriptor<VideoRecord>())
    #expect(results.count == 1)
    #expect(results.first?.title == "Test")
}
```

---

## Rust Testing (`cargo test` — 43 tests, all passing)

Tests use `#[cfg(test)]` modules. Large test modules are extracted to separate files via `#[path]` attributes (Phase 12).

| Module | Test File | Test Count | What's Tested |
|--------|-----------|-----------|---------------|
| ai/transcribe.rs | (inline) | 6 | File not found, file too large (>25MB), response parsing (wiremock), no words, empty words, MIME detection |
| ai/llm.rs | ai/llm_tests.rs | 11 | parse_chapters (valid/code-fenced/bare-fence/invalid/empty/unique-ids), truncate_transcript (short/long/boundary), validate_provider (OpenAI/Claude) |
| audio/filler.rs | (inline) | 12 | Punctuation stripping, all singles, all multis, clean speech, consecutive, single word, sorting, count |
| audio/silence.rs | audio/silence_tests.rs | 5 | File not found, all silent, sine wave, silence between tones, below min duration (programmatic WAV generation) |
| gif_export.rs | gif_export_tests.rs | 7 | Empty manifest, manifest not found, single/multi frame, progress callback, PNG RGBA/RGB loading |
| lib.rs | (inline) | 2 | hello_from_rust, cloom_core_version |

### Test Fixtures

`cloom-core/tests/fixtures/` contains:
- `transcription_response.json` — Mock OpenAI whisper-1 verbose_json response
- `chat_completion_response.json` — Mock OpenAI gpt-4o-mini response
- `chapters_response.json` — Mock chapters generation response

### Rust Test Dependencies

| Crate | Purpose |
|-------|---------|
| `wiremock 0.6` | HTTP mocking for AI API tests |
| `tempfile 3` | Temporary files/dirs for GIF and silence tests |
| `tokio 1` (macros) | Async test utilities |

### Silence Detection Test Pattern (Programmatic WAV)

```rust
fn create_test_wav(samples: &[i16], sample_rate: u32) -> PathBuf {
    // Writes WAV header + PCM samples to temp file
    // Used for: all_silent, sine_wave, silence_between_tones tests
}
```

---

## CI Pipeline (GitHub Actions)

`.github/workflows/tests.yml` runs on PRs to main:

### Job 1: rust-tests (macOS-15)
1. Install Rust + aarch64-apple-darwin target
2. `cargo test --verbose` in cloom-core/
3. Result: 43 tests pass

### Job 2: swift-tests (macOS-26)
1. Install Rust + aarch64-apple-darwin target
2. Run `./build.sh` (build Rust + generate bindings)
3. Run `xcodegen generate`
4. Run `xcodebuild test -scheme Cloom -destination 'platform=macOS,arch=arm64' -only-testing:CloomTests`
5. Result: 32 Swift unit tests pass

---

## What's NOT Tested (Areas for Future Improvement)

- **Recording integration tests:** Record screen → verify MP4 exists (requires TCC permissions in CI)
- **Compositing tests:** Verify webcam overlay + annotation burn-in in output frames (mock CMSampleBuffers)
- **Export round-trip tests:** Trim/cut/stitch → export → verify duration
- **AI integration tests:** End-to-end pipeline with mock API (Swift side)
- **Library search/filter tests:** SwiftData predicate filtering
- **Snapshot tests:** Visual regression via swift-snapshot-testing
- **Performance tests:** Frame processing latency, memory usage

---

## Verification Approach

1. **Phase 1A:** `build.sh` compiles Rust + Swift. App launches in menu bar. Rust FFI returns a value. SwiftData container initializes.
2. **Phase 1B–10:** Manual end-to-end test of each phase's features after implementation.
3. **Phase 11:** Automated tests (43 Rust + 32 Swift) + CI pipeline.
4. **Per-commit:** CI runs both Rust and Swift test suites on PRs.
