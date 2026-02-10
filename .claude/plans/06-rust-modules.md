# Rust Modules Detail (cloom-core/)

Rust's role is focused: AI API clients, audio analysis, and GIF export. Video encoding, compositing, data persistence, config, and MP4 export are all handled by Swift.

---

## audio/ — Audio Processing

**Responsibilities:**
- Silence detection: decode audio file (AAC/M4A/WAV) via symphonia, identify silent regions above threshold duration
- Audio level metering (RMS/peak for waveform display)
- Filler word identification: scan transcript words for "um", "uh", "like", "you know", etc.

**Key Files:**
- `silence.rs` — Decodes audio via symphonia, finds silent regions by amplitude threshold. Returns `Vec<TimeRange>`.
- `filler.rs` — Pattern-matches `TranscriptWord` list against filler word dictionary. Returns `Vec<FillerWord>` with counts.
- `mod.rs` — Audio module entry, `compute_audio_level()` for waveform data

**Crates:** `symphonia` (audio decoding — handles AAC, M4A, WAV, MP3, FLAC)

**Note:** `symphonia` replaces `hound`. Unlike `hound` (WAV-only), `symphonia` decodes AAC audio directly from screen recording MP4 files without any format conversion on the Swift side.

---

## ai/ — AI API Clients

**Responsibilities:**
- OpenAI transcription API: upload audio file, receive word-level transcription (`gpt-4o-mini-transcribe` default in v1)
- OpenAI LLM API (v1): send transcript, receive title/summary/chapters
- Retry logic, error handling
- API key received from Swift side as function parameter (not stored in Rust)
- Provider/model abstraction retained in FFI types for future expansion

**Key Files:**
- `transcribe.rs` — `transcribe_audio()`: multipart upload to transcription API, parse word-level response
- `llm.rs` — `generate_title()`, `generate_summary()`, `generate_chapters()`: OpenAI prompt templates, response parsing (provider-aware API surface for future)

**Crates:** `reqwest` (HTTP client), `serde` + `serde_json` (serialization), `tokio` (async runtime)

### Transcription API Flow
1. Read audio file from disk (path received from Swift)
2. POST multipart to `https://api.openai.com/v1/audio/transcriptions` (v1 default model: `gpt-4o-mini-transcribe`)
3. Parse response with word-level timestamps
4. Return `Transcript` struct via FFI

### LLM Prompts (OpenAI in v1)
- **Title:** "Generate a concise title for this recording based on the transcript: ..."
- **Summary:** "Summarize the key points of this recording in 2-3 sentences: ..."
- **Chapters:** "Divide this transcript into logical chapters with titles and start times: ..."

---

## export/ — GIF Export

**Responsibilities:**
- Read source MP4 file
- Extract frames at reduced rate (max 10 FPS)
- Resize to configurable max width (default 640px)
- Color quantization (NeuQuant or median cut)
- Frame differencing (only encode changed pixels)
- Encode to GIF format
- Progress reporting via callback

**Key Files:**
- `gif.rs` — `export_gif()`: frame extraction, resize, quantize, encode

**Crates:** `gif` (GIF encoding), `image` (frame decoding/resizing from MP4 frames)

### GIF Optimization
- Max 10 FPS, max 640px width
- NeuQuant or median cut color quantization
- Frame differencing (only encode changed pixels)
- Show estimated file size during export configuration (via progress callback)

**Decision:** Swift extracts/resamples frames from MP4 (e.g., `AVAssetImageGenerator`/`AVAssetReader`) and passes frame data paths to Rust. Rust focuses on quantization, differencing, and GIF encoding.

---

## lib.rs — FFI Entry Point

**Responsibilities:**
- All `#[uniffi::export]` function definitions
- All FFI type definitions (`#[derive(uniffi::Record)]`, `#[derive(uniffi::Enum)]`)
- Error type definition
- Callback interface definitions
- `uniffi::setup_scaffolding!()` macro

**This is the single entry point for all Rust↔Swift communication.**
