use thiserror::Error;

#[derive(Error, Debug)]
#[allow(dead_code)]
pub enum AppError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Reqwest error: {0}")]
    Reqwest(#[from] reqwest::Error),

    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("Notify error: {0}")]
    Notify(String),

    #[error("Recording error: {0}")]
    Recording(String),

    #[error("Transcription error: {0}")]
    Transcription(String),

    #[error("File error: {0}")]
    File(String),

    #[error("API error: {0}")]
    Api(String),

    #[error("Unknown error")]
    Unknown,
}

impl From<notify::Error> for AppError {
    fn from(err: notify::Error) -> Self {
        AppError::Notify(err.to_string())
    }
}

impl AppError {
    pub fn to_string(&self) -> String {
        match self {
            AppError::Io(e) => format!("IO error: {}", e),
            AppError::Reqwest(e) => format!("Network error: {}", e),
            AppError::Json(e) => format!("JSON error: {}", e),
            AppError::Notify(e) => format!("File watch error: {}", e),
            AppError::Recording(e) => format!("Recording error: {}", e),
            AppError::Transcription(e) => format!("Transcription error: {}", e),
            AppError::File(e) => format!("File error: {}", e),
            AppError::Api(e) => format!("API error: {}", e),
            AppError::Unknown => "Unknown error".to_string(),
        }
    }
}

pub type Result<T> = std::result::Result<T, AppError>;
