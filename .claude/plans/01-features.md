# Feature Categories (A-K)

Feature codes are referenced throughout the implementation phases (08-implementation-phases.md).

---

## A: Screen Recording

| Code | Feature | Description |
|------|---------|-------------|
| A1 | Screen + Webcam recording | Record screen and webcam simultaneously as separate streams, composited during export |
| A2 | Full-screen capture | Capture entire display via SCRecordingOutput |
| A3 | Screen-only recording | Record screen without webcam |
| A4 | Direct-to-file recording | Zero-copy hardware-accelerated recording via SCRecordingOutput |
| A5 | Window capture | Capture a specific application window |
| A6 | Region capture | Capture a user-selected rectangular area |
| A7 | Multi-monitor support | Enumerate and select from multiple displays |
| A8 | System audio capture | Record system/app audio via SCStreamConfiguration |
| A9 | Microphone capture | Record microphone audio via AVCaptureSession |
| A10 | Recording countdown | 3-2-1 visual countdown before recording starts |
| A11 | Pause/Resume | Pause and resume recording with seamless PTS adjustment |
| A12 | Recording state machine | Central state management: idle → countdown → recording → paused → stopped |

---

## B: Webcam

| Code | Feature | Description |
|------|---------|-------------|
| B1 | Webcam bubble overlay | Circular floating NSPanel showing camera preview |
| B2 | Draggable bubble | Drag webcam bubble to any screen position |
| B3 | Resizable bubble | Small (120pt), medium (180pt), large (280pt) sizes |
| B4 | Corner snapping | Bubble snaps to screen corners |
| B5 | Background blur | Person segmentation via Vision framework + CIFilter blur |
| B6 | Virtual backgrounds | Replace background using segmentation mask as alpha channel |

---

## C: Controls & UI

| Code | Feature | Description |
|------|---------|-------------|
| C1 | Floating control bar | Compact NSPanel with stop, pause, mute, draw, timer |
| C2 | Menu bar integration | MenuBarExtra for quick access to recording and library |
| C3 | Global keyboard shortcuts | Customizable hotkeys via Carbon `RegisterEventHotKey` |
| C4 | Mic mute/unmute | Toggle microphone during recording without stopping |
| C5 | Recording timer | Elapsed time display in control bar |

---

## D: Drawing & Annotations

| Code | Feature | Description |
|------|---------|-------------|
| D1 | Pen tool | Freehand drawing on transparent overlay |
| D2 | Highlighter | Semi-transparent (0.3 opacity) freehand strokes |
| D3 | Arrow tool | Draw arrows pointing to areas of interest |
| D4 | Rectangle tool | Draw rectangles on screen |
| D5 | Ellipse tool | Draw ellipses/circles on screen |
| D6 | Color picker & stroke width | Choose stroke color and line width |
| D7 | Eraser & undo/redo | Erase strokes, undo/redo stack |
| D8 | Mouse click emphasis | Expanding ripple effect on mouse clicks via CGEvent tap |
| D9 | Cursor spotlight | Radial gradient highlight around cursor position |

---

## E: Editor

| Code | Feature | Description |
|------|---------|-------------|
| E1 | Trim start/end | Drag handles to trim from beginning or end |
| E2 | Cut sections | Split and delete middle portions |
| E3 | Stitch clips | Join multiple recording segments |
| E4 | Timeline scrubber | Horizontal scrolling timeline with audio waveform |
| E5 | Speed adjustment | Change playback/export speed for segments |
| E6 | Thumbnail selection | Choose a frame as the video thumbnail |

---

## F: AI Features

| Code | Feature | Description |
|------|---------|-------------|
| F1 | Transcription | Word-level transcription via OpenAI `gpt-4o-mini-transcribe` (Rust client, swappable provider/model) |
| F2 | Auto-generate title | LLM generates concise title from transcript (Rust client) |
| F3 | Auto-generate summary | LLM generates 2-3 sentence summary (Rust client) |
| F4 | Auto-generate chapters | LLM divides transcript into logical chapters with timestamps (Rust client) |
| F5 | Filler word detection | Identify "um", "uh", "like", "you know" in transcript (Rust) |
| F6 | Silence detection | Detect silent regions in audio for auto-removal (Rust + symphonia) |

---

## G: Player

| Code | Feature | Description |
|------|---------|-------------|
| G1 | Basic video playback | AVPlayer wrapper with play/pause/seek |
| G2 | Caption overlay | Render SRT/VTT captions from transcript |
| G3 | Speed control | 0.5x, 1x, 1.5x, 2x playback speed |
| G4 | Fullscreen | Full-screen video playback |
| G5 | Picture-in-Picture | PiP via AVPictureInPictureController |
| G6 | Transcript panel | Scrolling transcript synced to playback, click-to-seek |
| G7 | Chapter navigation | Jump between AI-detected chapters |

---

## H: Export & Sharing

| Code | Feature | Description |
|------|---------|-------------|
| H1 | Auto-copy file path | Copy exported file path to clipboard |
| H2 | MP4 export with EDL | Apply EditDecisionList (trims, cuts, speed) via AVMutableComposition (Swift) |
| H3 | GIF export | Generate optimized GIF with color quantization (Rust gif crate) |

---

## I: Library & Organization

| Code | Feature | Description |
|------|---------|-------------|
| I1 | Full-text search | Search titles + transcript content (SwiftData metadata + local SQLite FTS via GRDB) |
| I2 | Folder management | Create, rename, delete, nest folders |
| I3 | Tags & labels | Color-coded tags on videos |
| I4 | Sort & filter | Sort by date, name, duration; filter by folder/tag |
| I5 | Thumbnail previews | Video thumbnails in grid/list view |

---

## J: Settings & Polish

| Code | Feature | Description |
|------|---------|-------------|
| J1 | Video quality settings | Select 720p / 1080p / 1440p / native quality |
| J2 | Frame rate settings | Select 24 / 30 / 60 FPS |
| J3 | Codec selection | H.264 or H.265 |
| J4 | Launch at startup | SMAppService integration |
| J5 | Keyboard shortcut customization | Remap global hotkeys |
| J6 | Dark mode | System / light / dark mode preference |
| J7 | Notifications | Post-recording notifications via UNUserNotificationCenter |
| J8 | Noise cancellation | Audio noise reduction |

---

## K: Analytics & Advanced

| Code | Feature | Description |
|------|---------|-------------|
| K1 | Local view analytics | Track view count, watch time, completion rate |
| K2 | Timestamped comments | Add comments at specific video timestamps |
