# Rust Modules Detail (cloom-core/)

Rust's role is focused: AI API clients, audio analysis, and GIF export. Video encoding, compositing, data persistence, config, MP4 export, and waveform generation are all handled by Swift.

**Total: 12 source files, ~1,700 lines of code, 43 tests (inline + extracted test files).**

---

## audio/ — Audio Processing (4 files)

**Responsibilities:**
- Silence detection: decode audio file (AAC/M4A/WAV) via symphonia, identify silent regions by RMS amplitude threshold
- Filler word identification: scan transcript words for common filler patterns (single + multi-word)

**Key Files:**
- `silence.rs` — `SilenceDetector` struct. `detect_silence()` decodes audio via symphonia, computes RMS per 10ms window, finds regions below threshold for minimum duration. Returns `Vec<TimeRange>`. Pre-allocated Vecs for performance.
- `silence_tests.rs` — **5 tests:** file not found, all silent, sine wave, silence between tones, below min duration (programmatic WAV generation). Extracted via `#[path]` attribute.
- `filler.rs` — `FillerWordDetector` struct. `detect_fillers()` scans `TranscriptWord` list via case-insensitive matching. Single-word: uh, um, like, basically, literally, actually, honestly, right, so. Multi-word (sliding window): you know, i mean, sort of, kind of. Returns `Vec<FillerWord>` with word + count. **12 tests:** punctuation stripping, all singles, all multis, clean speech, consecutive, sorting, count.
- `mod.rs` — Module re-exports

**Crates:** `symphonia` (audio decoding — handles AAC, M4A, WAV, MP3, FLAC from MP4 containers)

> **Note:** Waveform/audio level computation is done in Swift (WaveformGenerator.swift using AVAssetReader), not in Rust. The originally planned `compute_audio_level()` function was not implemented.

---

## ai/ — AI API Clients (4 files)

**Responsibilities:**
- OpenAI transcription API: upload audio file, receive word-level transcription via `whisper-1`
- OpenAI LLM API: send transcript, receive title/summary/chapters via `gpt-4o-mini`
- Error handling, file size validation (≤25MB)
- API key received from Swift side as function parameter (not stored in Rust)
- Provider abstraction retained in types (`LlmProvider`, `TranscriptionProvider`) for future expansion

**Key Files:**
- `transcribe.rs` — `TranscriptionClient` struct. `transcribe_audio()`: multipart upload to `https://api.openai.com/v1/audio/transcriptions` with model `whisper-1`, `response_format: verbose_json`, `timestamp_granularities: word`. Validates file size (≤25MB), detects MIME type. Parses word-level timestamps from response. Returns `Transcript` struct. **6 tests:** file not found, file too large, response parsing, no words, empty words, MIME detection (wiremock fixtures).
- `llm.rs` — `LlmClient` struct. Provider-aware: `LlmProvider::OpenAi` enabled, `LlmProvider::Claude` returns error. Uses `gpt-4o-mini` model via `https://api.openai.com/v1/chat/completions`.
  - `generate_title()` — prompt: "Generate a concise title (max 10 words)"
  - `generate_summary()` — prompt: "Summarize key points in 2-3 sentences"
  - `generate_chapters()` — prompt: "Divide into chapters with timestamps", parses JSON array (supports code-fenced, bare-fenced, and raw JSON styles). Returns `Vec<Chapter>` with unique IDs.
  - `format_paragraphs()` — adds paragraph breaks to raw transcript via LLM
  - `truncate_transcript()` — truncates to ~8000 chars for LLM context
  - `validate_provider()` — checks provider support
- `llm_tests.rs` — **11 tests:** parse_chapters (valid/code-fenced/bare-fence/invalid/empty/unique-ids), truncate (short/long/boundary), validate_provider (OpenAI/Claude). Extracted via `#[path]` attribute.
- `mod.rs` — Module re-exports

**Crates:** `reqwest` (HTTP client), `serde` + `serde_json` (serialization), `tokio` (async runtime)

### Transcription API Flow
1. Read audio file from disk (path received from Swift)
2. Validate file size ≤ 25MB
3. POST multipart to `https://api.openai.com/v1/audio/transcriptions` with model `whisper-1`
4. Parse `verbose_json` response with word-level timestamps
5. Return `Transcript` struct via FFI

### LLM API Flow
1. Truncate transcript to ~8000 chars if needed
2. POST to `https://api.openai.com/v1/chat/completions` with model `gpt-4o-mini`
3. Parse response (title/summary as plain text, chapters as JSON array)
4. Return result via FFI

---

## gif_export.rs — GIF Export (2 files, root level)

**Responsibilities:**
- Read PNG frames manifest from disk (JSON file listing PNG paths)
- Load PNG frames (supports RGBA and RGB formats)
- Encode via gifski with configurable width, FPS, and quality
- Progress reporting via callback

**Key Types:**
- `GifConfig` (uniffi::Record) — width, height, fps, quality, repeat_count
- `GifExporter` struct
- `export_gif(manifest_path, output_path, config, progress_callback)` — reads PNG manifest → loads frames → gifski encoder → GIF file

**Crates:** `gifski` (GIF encoding with color quantization), `png` (PNG decoding), `imgref` + `rgb` (image frame types)

- `gif_export_tests.rs` — **7 tests:** empty manifest, manifest not found, single/multi frame, progress callback, PNG RGBA/RGB loading. Extracted via `#[path]` attribute.

### GIF Export Flow
1. Swift extracts frames from MP4 at reduced rate (via AVAssetImageGenerator)
2. Swift writes PNG files + manifest JSON to temp directory
3. Rust reads manifest, loads PNG frames
4. gifski encodes with color quantization and frame differencing
5. Progress reported via callback interface
6. Output GIF written to specified path

---

## runtime.rs — Shared Async Runtime (1 file)

**Responsibilities:**
- Provides a shared Tokio runtime via `LazyLock<Runtime>` singleton
- All async FFI functions (AI, transcription) use this runtime instead of creating per-call thread pools
- Eliminates ~4ms thread pool startup overhead per API call

**Key Types:**
- `RUNTIME: LazyLock<Runtime>` — shared multi-threaded Tokio runtime

**Crates:** `tokio` (rt-multi-thread)

---

## lib.rs — FFI Entry Point (1 file)

**Responsibilities:**
- `uniffi::setup_scaffolding!()` macro for UniFFI proc macro setup
- `CloomError` error enum definition (IoError, ApiError, AudioError, InvalidInput, ExportError)
- Utility FFI functions: `hello_from_rust()`, `cloom_core_version()`
- Module declarations for `ai`, `audio`, `gif_export`, `runtime`

**2 unit tests:** hello_from_rust, cloom_core_version

**This is the single entry point for all Rust↔Swift communication.**
