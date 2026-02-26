/// Shared Tokio runtime for all AI API calls.
/// Avoids spawning a new thread pool per request.
pub static RUNTIME: std::sync::LazyLock<tokio::runtime::Runtime> =
    std::sync::LazyLock::new(|| {
        tokio::runtime::Runtime::new().expect("Failed to create Tokio runtime")
    });
