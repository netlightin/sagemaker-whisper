use crate::errors::{AppError, Result};
use reqwest::multipart;
use std::path::Path;
use tokio::fs::File;

#[allow(dead_code)]
const API_ENDPOINT: &str = "http://loud-meadow-alb-235533752.eu-west-1.elb.amazonaws.com/transcribe";
#[allow(dead_code)]
const API_KEY: &str = "e20ce61a459e49ed9319ceab0f72b5d1";

pub struct ApiClient {
    client: reqwest::Client,
}

impl ApiClient {
    pub fn new() -> Self {
        Self {
            client: reqwest::Client::new(),
        }
    }

    pub async fn transcribe_audio(&self, file_path: &Path) -> Result<String> {
        if !file_path.exists() {
            return Err(AppError::File(format!(
                "File not found: {}",
                file_path.display()
            )));
        }

        let file_name = file_path
            .file_name()
            .ok_or_else(|| AppError::File("Invalid file name".to_string()))?
            .to_string_lossy()
            .to_string();

        let file = File::open(file_path).await?;

        let form = multipart::Form::new()
            .part("audio", multipart::Part::stream(file).file_name(file_name));

        let response = self
            .client
            .post(API_ENDPOINT)
            .header("x-api-key", API_KEY)
            .multipart(form)
            .timeout(std::time::Duration::from_secs(300))
            .send()
            .await
            .map_err(|e| AppError::Api(format!("Failed to send request: {}", e)))?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response
                .text()
                .await
                .unwrap_or_else(|_| "Unknown error".to_string());
            return Err(AppError::Api(format!(
                "API error {}: {}",
                status, body
            )));
        }

        let body = response
            .text()
            .await
            .map_err(|e| AppError::Api(format!("Failed to read response: {}", e)))?;

        let transcript = extract_transcript(&body)?;

        Ok(transcript)
    }
}

#[allow(dead_code)]
fn extract_transcript(body: &str) -> Result<String> {
    match serde_json::from_str::<serde_json::Value>(body) {
        Ok(json) => {
            if let Some(text) = json.get("text").and_then(|t| t.as_str()) {
                Ok(text.to_string())
            } else {
                Err(AppError::Api(
                    "Response missing 'text' field".to_string(),
                ))
            }
        }
        Err(e) => Err(AppError::Json(e)),
    }
}

impl Default for ApiClient {
    fn default() -> Self {
        Self::new()
    }
}
