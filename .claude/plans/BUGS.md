# Cloom — Bug Fix Log

Chronological record of bugs fixed, with root cause analysis and PR links.

---

## #37 — Subtitle export fails with "The operation could not be completed"
**Date:** 2026-03-03
**PR:** [#37](https://github.com/iamsachin/cloom/pull/37)

**Symptom:** Exporting with "Include Subtitles" enabled fails on `AVAssetWriter.finishWriting()` with a generic error.

**Root cause:** `makeTx3gFormatDescription()` used raw MP4 box-path binary blobs (`"mdia"/"minf"/"stbl"/"stsd"/"tx3g"`) as `CMFormatDescription` extensions. These are invalid keys — Apple expects named `kCMTextFormatDescription*` constants (`DisplayFlags`, `BackgroundColor`, `DefaultTextBox`, `DefaultStyle`, `FontTable`, etc.).

**Fix:** Rewrote `makeTx3gFormatDescription()` with Apple's named extension keys and `kCMTextFormatType_3GText`. Simplified `ExportService` to 4 clear export paths. Removed debug logging.

---

## #36 — Export deadlock and unnecessary video re-encode
**Date:** 2026-03-01
**PR:** [#36](https://github.com/iamsachin/cloom/pull/36)

**Symptom:** Export hangs indefinitely or takes much longer than expected.

**Root cause:** (1) AVAssetWriter deadlocks when tracks are fed sequentially instead of concurrently. (2) Video was being re-encoded during export instead of using passthrough, wasting time and quality.

**Fix:** Fed all AVAssetWriter tracks (video, audio, subtitles) concurrently using `withTaskGroup`. Removed unnecessary video re-encode — passthrough copy for unmodified exports.

---

## #34 — Cuts at timeline start silently skipped in buildTimeRanges
**Date:** 2026-03-01
**PR:** [#34](https://github.com/iamsachin/cloom/pull/34)

**Symptom:** Cuts placed at the very start of the timeline (cutStart == currentMs) were ignored during export — the cut region remained in the output video.

**Root cause:** `EditorCompositionBuilder.buildTimeRanges` had `guard cutStart > currentMs` which prevented advancing `currentMs` past cuts that started exactly at the current position.

**Fix:** Changed guard to `guard cutStart >= currentMs` so cuts at the start of the timeline are processed correctly. Discovered by new test coverage.

---

## #32 — Passthrough export crash on Drive upload
**Date:** 2026-02-28
**PR:** [#32](https://github.com/iamsachin/cloom/pull/32)

**Symptom:** Uploading to Google Drive crashes when the export used passthrough copy (no edits, no subtitles).

**Root cause:** Passthrough copy used `FileManager.copyItem` to the temp URL, but the upload flow expected the temp file to exist with specific naming. Race condition between copy and upload.

**Fix:** Ensured temp file lifecycle is correct for the Drive upload path.

---

## #28 — Long recording stress test failures
**Date:** 2026-02-27
**PR:** [#28](https://github.com/iamsachin/cloom/pull/28)

**Symptom:** Recordings over ~5 minutes showed frame drops, memory growth, and potential crashes.

**Root cause:** Per-frame person segmentation was expensive, no frame throttling, CIContext instances were not shared across the pipeline, and Rust FFI created a new Tokio runtime per call.

**Fix:** Throttled PersonSegmenter to every 5th frame with cached mask. Shared CIContext singleton (Metal-backed). Shared Tokio runtime via `LazyLock`. Added `OSAllocatedUnfairLock` for cross-queue state in ScreenCaptureService.

---

## #23 — Chapter timestamps inaccurate and waveform too sparse
**Date:** 2026-02-26
**PR:** [#23](https://github.com/iamsachin/cloom/pull/23)

**Symptom:** Chapter markers were placed at wrong timestamps. Waveform visualization looked empty/sparse for normal speech.

**Root cause:** Chapter timestamps from the LLM were based on transcript word indices rather than actual millisecond times. Waveform noise floor was too aggressive, suppressing normal speech levels.

**Fix:** Fixed chapter timestamp mapping to use actual word start times. Adjusted waveform noise floor sensitivity.

---

## #22 — Real-time drawing not rendering during mouse drag
**Date:** 2026-02-26
**PR:** [#22](https://github.com/iamsachin/cloom/pull/22)

**Symptom:** Drawing annotations on screen during recording only appeared after releasing the mouse — no live preview while drawing.

**Root cause:** The drawing overlay was only updating on `mouseUp`, not during `mouseDragged` events.

**Fix:** Added real-time rendering during `mouseDragged` so strokes appear as they are drawn.

---

## #19 — Audio export bugs (silent output, missing tracks)
**Date:** 2026-02-25
**PR:** [#19](https://github.com/iamsachin/cloom/pull/19)

**Symptom:** Exported videos had silent audio or missing audio tracks. Multiple audio sources (system + mic) not mixed correctly.

**Root cause:** Multiple audio tracks were not being mixed down to stereo during export. `AVMutableAudioMix` with `AVMutableAudioMixInputParameters` was not being applied.

**Fix:** Added `AVMutableAudioMix` with volume 1.0 input parameters for all audio tracks. Multi-track audio now mixes to stereo on export.

---

## #17 — Webcam compositing offset and library toolbar issues
**Date:** 2026-02-25
**PR:** [#17](https://github.com/iamsachin/cloom/pull/17)

**Symptom:** Webcam bubble appeared at wrong position in exported video. Library toolbar buttons misaligned.

**Root cause:** CIImage flip extent issue — `scaleX: -1` shifts CIImage extent to negative coordinates. Wrong extents caused `.composited(over:)` to expand the canvas incorrectly.

**Fix:** Used `scaleX: -scaleFactor` + `translationX: width * scaleFactor` to keep extent at origin.

---

## #16 — Waveform invisible and library timestamps wrong
**Date:** 2026-02-25
**PR:** [#16](https://github.com/iamsachin/cloom/pull/16)

**Symptom:** Waveform visualization was invisible for most recordings. Library showed incorrect duration timestamps.

**Root cause:** Waveform noise floor threshold was too high, suppressing all audio below a certain level. Library duration formatting used wrong time conversion.

**Fix:** Adjusted noise floor sensitivity. Fixed duration formatting.

---

## #15 — UI bugs in waveform, webcam bubble, and tooltips
**Date:** 2026-02-25
**PR:** [#15](https://github.com/iamsachin/cloom/pull/15)

**Symptom:** Various visual glitches — waveform rendering issues, webcam bubble positioning, broken tooltips.

**Root cause:** Multiple small UI issues accumulated during rapid feature development.

**Fix:** Fixed waveform rendering, webcam bubble layout, and tooltip display.

---

## #2 — Content picker fails without Screen Recording TCC permission
**Date:** 2026-02-11
**PR:** [#2](https://github.com/iamsachin/cloom/pull/2)

**Symptom:** Custom window picker using `SCShareableContent` couldn't list other apps' windows.

**Root cause:** `SCShareableContent.current` requires Screen Recording TCC permission. Custom pickers can't enumerate windows without it, and debug builds reset TCC on every rebuild.

**Fix:** Replaced custom ContentPicker with Apple's `SCContentSharingPicker` which handles permissions automatically via the system picker UI.
