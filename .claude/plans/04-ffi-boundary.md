# FFI Boundary (Swift ↔ Rust via UniFFI)

## Technology: UniFFI 0.31 (Mozilla)

- Generates idiomatic Swift bindings from Rust interface definitions
- Uses `#[uniffi::export]` proc macros exclusively (no UDL files)
- Supports async, callbacks, complex types, error handling
- Rust `Result<T, E>` → Swift `throws`
- Local binary: `cd cloom-core && cargo run --bin uniffi-bindgen` (not global CLI)

## What Crosses the Bridge

The FFI surface is intentionally small. Only audio processing, AI API calls, and GIF export go through Rust. Everything else (data persistence, video encoding, compositing, config, MP4 export, waveform generation) is handled entirely in Swift.

### Swift → Rust: Audio Processing

| Function | Signature | Description |
|----------|-----------|-------------|
| `detect_silence` | `(audio_path: String, threshold_db: f32, min_duration_ms: u64) → Vec<TimeRange>` | Find silent regions in audio file (symphonia decodes AAC/M4A/WAV) |
| `identify_filler_words` | `(words: Vec<TranscriptWord>) → Vec<FillerWord>` | Scan transcript words for "um", "uh", "like", "you know", etc. |

> **Note:** Waveform/audio level computation is done in Swift (WaveformGenerator.swift) using AVAssetReader, not via Rust FFI.

### Swift → Rust: AI (async)

| Function | Signature | Description |
|----------|-----------|-------------|
| `transcribe_audio` | `(audio_path: String, api_key: String, provider: TranscriptionProvider, model: String) → Transcript` | Upload audio to OpenAI whisper-1, return word-level transcript |
| `generate_title` | `(transcript_text: String, api_key: String, provider: LlmProvider) → String` | Generate concise title via gpt-4o-mini |
| `generate_summary` | `(transcript_text: String, api_key: String, provider: LlmProvider) → String` | Generate 2-3 sentence summary via gpt-4o-mini |
| `generate_chapters` | `(transcript_text: String, api_key: String, provider: LlmProvider) → Vec<Chapter>` | Divide transcript into chapters via gpt-4o-mini |
| `format_paragraphs` | `(transcript_text: String, api_key: String, provider: LlmProvider) → String` | Add paragraph breaks to raw transcript via gpt-4o-mini |

`LlmProvider` stays in the interface for forward compatibility. In v1, only `OpenAi` is enabled; `Claude` returns `CloomError::InvalidInput`.

`TranscriptionProvider` stays in the interface for forward compatibility. In v1, only `OpenAi` is enabled with `whisper-1` model.

### Swift → Rust: GIF Export (async)

| Function | Signature | Description |
|----------|-----------|-------------|
| `export_gif` | `(manifest_path: String, output_path: String, config: GifConfig, progress: Box<dyn GifProgressCallback>) → String` | Read PNG manifest, encode GIF via gifski |

### Utility Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `hello_from_rust` | `(name: String) → String` | FFI smoke test |
| `cloom_core_version` | `() → String` | Returns crate version string |

## FFI Type Definitions

All types that cross the boundary are defined in Rust with `#[derive(uniffi::Record)]` or `#[derive(uniffi::Enum)]` and auto-generated into Swift by UniFFI.

### Records

```rust
TimeRange { start_ms: u64, end_ms: u64 }
FillerWord { word: String, start_ms: u64, end_ms: u64, count: u32 }
TranscriptWord { word: String, start_ms: u64, end_ms: u64, confidence: f32 }
Transcript { full_text: String, words: Vec<TranscriptWord>, language: String }
Chapter { id: String, title: String, start_ms: u64 }
GifConfig { width: u32, height: u32, fps: u8, quality: u8, repeat_count: i16 }
```

### Enums

```rust
LlmProvider { OpenAi, Claude }
TranscriptionProvider { OpenAi }
CloomError { IoError, ApiError, AudioError, InvalidInput, ExportError }
```

### Callback Interfaces

```rust
#[uniffi::export(callback_interface)]
trait GifProgressCallback: Send + Sync {
    fn on_progress(&self, fraction: f32);  // 0.0 → 1.0
}
```

## Data Marshalling Strategy

| Data Type | Strategy |
|-----------|----------|
| Structs/Enums | UniFFI auto-generates Swift equivalents |
| Strings | UniFFI auto-converts `String` ↔ `Swift.String` |
| Callbacks | UniFFI callback interfaces (Rust trait → Swift protocol) |
| File paths | `String` on both sides (Rust reads files directly from disk) |
| Errors | Rust `Result<T, CloomError>` → Swift `throws` |
| Audio data | NOT passed over FFI — Rust reads audio files directly via path |
| Video frames | NOT passed over FFI — Swift extracts PNG frames to disk, Rust reads PNG manifest |

## Build Integration

`build.sh` orchestrates (Apple Silicon):
1. `cargo build --release --target aarch64-apple-darwin` → `target/aarch64-apple-darwin/release/libcloom_core.a`
2. `cd cloom-core && cargo run --bin uniffi-bindgen generate --library ../target/aarch64-apple-darwin/release/libcloom_core.dylib --language swift --out-dir ../CloomApp/Sources/Bridge/Generated/`
3. Copy static library to `libs/libcloom_core.a`
4. Xcode Build Phase runs `build.sh` as pre-build script
5. Bridging header at `CloomApp/Sources/Bridge/Cloom-Bridging-Header.h` includes generated C header (workaround for Xcode 26 explicit module builds)
