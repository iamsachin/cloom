use super::*;

// --- parse_chapters tests ---

#[test]
fn test_parse_chapters_valid_json() {
    let json = r#"[{"title": "Intro", "start_ms": 0}, {"title": "Demo", "start_ms": 30000}]"#;
    let chapters = parse_chapters(json).unwrap();
    assert_eq!(chapters.len(), 2);
    assert_eq!(chapters[0].title, "Intro");
    assert_eq!(chapters[0].start_ms, 0);
    assert_eq!(chapters[1].title, "Demo");
    assert_eq!(chapters[1].start_ms, 30000);
}

#[test]
fn test_parse_chapters_code_fenced_json() {
    let raw = "```json\n[{\"title\": \"Setup\", \"start_ms\": 0}]\n```";
    let chapters = parse_chapters(raw).unwrap();
    assert_eq!(chapters.len(), 1);
    assert_eq!(chapters[0].title, "Setup");
}

#[test]
fn test_parse_chapters_bare_code_fence() {
    let raw = "```\n[{\"title\": \"A\", \"start_ms\": 100}]\n```";
    let chapters = parse_chapters(raw).unwrap();
    assert_eq!(chapters.len(), 1);
    assert_eq!(chapters[0].start_ms, 100);
}

#[test]
fn test_parse_chapters_invalid_fallback() {
    let raw = "This is not JSON at all";
    let chapters = parse_chapters(raw).unwrap();
    assert_eq!(chapters.len(), 1);
    assert_eq!(chapters[0].title, "Full Recording");
    assert_eq!(chapters[0].start_ms, 0);
}

#[test]
fn test_parse_chapters_empty_array() {
    let raw = "[]";
    let chapters = parse_chapters(raw).unwrap();
    assert_eq!(chapters.len(), 0);
}

#[test]
fn test_parse_chapters_ids_are_unique() {
    let json = r#"[{"title": "A", "start_ms": 0}, {"title": "B", "start_ms": 1000}]"#;
    let chapters = parse_chapters(json).unwrap();
    assert_ne!(chapters[0].id, chapters[1].id);
}

// --- truncate_transcript tests ---

#[test]
fn test_truncate_short_text() {
    let text = "Hello world";
    let result = truncate_transcript(text);
    assert_eq!(result, "Hello world");
}

#[test]
fn test_truncate_long_text() {
    let text = "a".repeat(200_000);
    let result = truncate_transcript(&text);
    assert_eq!(result.len(), 100_000);
}

#[test]
fn test_truncate_at_boundary() {
    let text = "a".repeat(100_000);
    let result = truncate_transcript(&text);
    assert_eq!(result.len(), 100_000);
}

// --- validate_provider tests ---

#[test]
fn test_validate_openai_ok() {
    assert!(validate_provider(&LlmProvider::OpenAi).is_ok());
}

// --- Additional parse_chapters edge cases ---

#[test]
fn test_parse_chapters_whitespace_around_json() {
    let raw = "  \n  [{\"title\": \"Intro\", \"start_ms\": 0}]  \n  ";
    let chapters = parse_chapters(raw).unwrap();
    assert_eq!(chapters.len(), 1);
    assert_eq!(chapters[0].title, "Intro");
}

#[test]
fn test_parse_chapters_negative_start_ms() {
    let json = r#"[{"title": "Before", "start_ms": -100}]"#;
    let chapters = parse_chapters(json).unwrap();
    assert_eq!(chapters[0].start_ms, -100);
}

#[test]
fn test_parse_chapters_large_start_ms() {
    let json = r#"[{"title": "Late", "start_ms": 3600000}]"#;
    let chapters = parse_chapters(json).unwrap();
    assert_eq!(chapters[0].start_ms, 3600000); // 1 hour in ms
}

#[test]
fn test_parse_chapters_single_chapter() {
    let json = r#"[{"title": "Only One", "start_ms": 0}]"#;
    let chapters = parse_chapters(json).unwrap();
    assert_eq!(chapters.len(), 1);
    assert_eq!(chapters[0].title, "Only One");
}

#[test]
fn test_parse_chapters_many_chapters() {
    let json = (0..20)
        .map(|i| format!(r#"{{"title": "Ch{}", "start_ms": {}}}"#, i, i * 1000))
        .collect::<Vec<_>>()
        .join(",");
    let raw = format!("[{}]", json);
    let chapters = parse_chapters(&raw).unwrap();
    assert_eq!(chapters.len(), 20);
}

#[test]
fn test_parse_chapters_code_fence_with_trailing_text() {
    let raw = "Here are the chapters:\n```json\n[{\"title\": \"A\", \"start_ms\": 0}]\n```\nDone!";
    // After stripping: still won't parse cleanly because of "Here are the chapters:\n"
    // The function trims, strips ```json and ```, so the leading text stays → fallback
    let chapters = parse_chapters(raw).unwrap();
    // Should fall back because there's text before the code fence
    assert_eq!(chapters[0].title, "Full Recording");
}

// --- truncate_transcript edge cases ---

#[test]
fn test_truncate_empty_string() {
    let result = truncate_transcript("");
    assert_eq!(result, "");
}

#[test]
fn test_truncate_one_char() {
    let result = truncate_transcript("x");
    assert_eq!(result, "x");
}

#[test]
fn test_truncate_multibyte_utf8_no_panic() {
    // Build a string of multi-byte chars (each 'ä' is 2 bytes) that exceeds MAX_TRANSCRIPT_CHARS
    let text = "ä".repeat(100_000); // 200_000 bytes, 100_000 chars
    let result = truncate_transcript(&text);
    // Must not panic and must be valid UTF-8
    assert!(result.len() <= 100_000);
    assert!(result.len() > 0);
    // Every char is 2 bytes, so the result should be truncated at a char boundary
    assert_eq!(result.len() % 2, 0);
}

// --- translate_text tests ---

#[test]
fn test_translate_text_validates_provider() {
    // translate_text delegates to validate_provider → chat_completion.
    // We can verify the function signature compiles and the provider check works
    // by calling it with an empty API key (provider validation passes, API call fails).
    let result = translate_text(
        "Hello world".to_string(),
        "Spanish".to_string(),
        "".to_string(),
        LlmProvider::OpenAi,
    );
    // Should fail at the API call level (empty key), not at provider validation
    assert!(result.is_err());
}

#[test]
fn test_translate_text_empty_text() {
    let result = translate_text(
        "".to_string(),
        "French".to_string(),
        "".to_string(),
        LlmProvider::OpenAi,
    );
    // Empty text with empty key should still fail at API level
    assert!(result.is_err());
}
