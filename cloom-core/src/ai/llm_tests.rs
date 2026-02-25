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

#[test]
fn test_validate_claude_error() {
    let result = validate_provider(&LlmProvider::Claude);
    assert!(result.is_err());
    if let Err(CloomError::InvalidInput { msg }) = result {
        assert!(msg.contains("Claude"));
    }
}
