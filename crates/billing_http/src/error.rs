use thiserror::Error;

pub type Result<T> = std::result::Result<T, BillingHttpError>;

#[derive(Debug, Error)]
pub enum BillingHttpError {
    #[error("HTTP {status}: {body}")]
    Http { status: u16, body: String },
    #[error("{0}")]
    Message(String),
    #[error(transparent)]
    Reqwest(#[from] reqwest::Error),
    #[error(transparent)]
    Json(#[from] serde_json::Error),
}

pub(crate) fn truncate_body(body: &str) -> String {
    const MAX: usize = 512;
    if body.len() <= MAX {
        body.to_string()
    } else {
        format!("{}…", &body[..MAX])
    }
}

pub(crate) fn unwrap_data(value: serde_json::Value) -> serde_json::Value {
    if let Some(data) = value.get("data").cloned() {
        return data;
    }
    value
}
