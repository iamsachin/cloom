# FFI Boundary (Swift ↔ Rust via UniFFI)

## Technology: UniFFI (Mozilla)

- Generates idiomatic Swift bindings from Rust interface definitions
- Uses `#[uniffi::export]` proc macros exclusively (no UDL files)
- Supports async, callbacks, complex types, error handling
- Rust `Result<T, E>` → Swift `throws`

## What Crosses the Bridge

The FFI surface is intentionally small. Only audio processing, AI API calls, and GIF export go through Rust. Everything else (data persistence, video encoding, compositing, config, MP4 export) is handled entirely in Swift.

### Swift → Rust: Audio Processing

| Function | Signature | Description |
|----------|-----------|-------------|
| `detect_silence` | `(audio_path: String, threshold_db: f32, min_duration_ms: u64) → Vec<TimeRange>` | Find silent regions in audio file (symphonia decodes AAC/M4A/WAV) |
| `identify_filler_words` | `(words: Vec<TranscriptWord>) → Vec<FillerWord>` | Scan transcript words for "um", "uh", "like", "you know", etc. |
| `compute_audio_level` | `(audio_path: String, window_ms: u64) → Vec<f32>` | Compute RMS audio levels for waveform display |

### Swift → Rust: AI (async)

| Function | Signature | Description |
|----------|-----------|-------------|
| `transcribe_audio` | `async (audio_path: String, api_key: String, provider: TranscriptionProvider, model: String) → Transcript` | Upload audio to provider/model (v1 default: OpenAI `gpt-4o-mini-transcribe`), return word-level transcript |
| `generate_title` | `async (transcript_text: String, api_key: String, provider: LlmProvider) → String` | Generate concise title from transcript |
| `generate_summary` | `async (transcript_text: String, api_key: String, provider: LlmProvider) → String` | Generate 2-3 sentence summary |
| `generate_chapters` | `async (transcript_text: String, api_key: String, provider: LlmProvider) → Vec<Chapter>` | Divide transcript into logical chapters |

`LlmProvider` stays in the interface for forward compatibility. In v1, only `OpenAI` is enabled; unsupported providers return `CloomError::InvalidInput`.

`TranscriptionProvider` and `model` stay in the interface for forward compatibility. In v1, only `OpenAI` is enabled and the default model is `gpt-4o-mini-transcribe`.

### Swift → Rust: GIF Export (async)

| Function | Signature | Description |
|----------|-----------|-------------|
| `export_gif` | `async (frames_manifest_path: String, config: GifConfig, output_path: String, progress: GifProgressCallback)` | Read pre-extracted frame list from Swift, quantize, encode GIF |

## FFI Type Definitions

All types that cross the boundary are defined in Rust with `#[derive(uniffi::Record)]` or `#[derive(uniffi::Enum)]` and auto-generated into Swift by UniFFI.

### Records

```rust
TimeRange { start_ms: u64, end_ms: u64 }
FillerWord { word: String, start_ms: u64, end_ms: u64, count: u32 }
TranscriptWord { word: String, start_ms: u64, end_ms: u64, confidence: f32 }
Transcript { full_text: String, words: Vec<TranscriptWord>, language: String }
Chapter { id: String, title: String, start_ms: u64 }
GifConfig { max_width: u32, max_fps: u32, start_ms: u64, end_ms: u64 }
```

### Enums

```rust
LlmProvider { OpenAI, Claude }
TranscriptionProvider { OpenAI }
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
| File paths | `String` on both sides (Rust reads manifest + frame files directly from disk) |
| Errors | Rust `Result<T, CloomError>` → Swift `throws` |
| Audio data | NOT passed over FFI — Rust reads audio files directly via path |

## Build Integration

`build.sh` orchestrates (Apple Silicon):
1. `cargo build --release --target aarch64-apple-darwin` → `target/aarch64-apple-darwin/release/libcloom_core.a`
2. `uniffi-bindgen generate --library target/aarch64-apple-darwin/release/libcloom_core.dylib --language swift --out-dir CloomApp/Sources/Bridge/Generated/`
3. Copy static library to known location
4. Xcode Build Phase runs script pre-compilation
