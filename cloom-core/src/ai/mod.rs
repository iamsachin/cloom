pub mod llm;
pub mod transcribe;

use async_openai::{config::OpenAIConfig, Client};

/// Build an OpenAI API client configured with the given key.
pub(crate) fn make_openai_client(api_key: &str) -> Client<OpenAIConfig> {
    let config = OpenAIConfig::new().with_api_key(api_key);
    Client::with_config(config)
}
