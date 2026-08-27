use reqwest::Client;
use serde::{Deserialize, Serialize};

use crate::error::{truncate_body, unwrap_data, BillingHttpError, Result};

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AgentTokenMintRequest {
    pub credential: serde_json::Value,
    pub proof: AgentProof,
    pub target_identity: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct AgentProof {
    pub ts: i64,
    pub signature: String,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AgentTokenMintResponse {
    pub token: String,
    pub expires_in: u64,
    #[serde(default)]
    pub token_type: Option<String>,
}

/// Better Auth host client for `POST /api/auth/agent/token`.
pub struct AgentTokenClient {
    http: Client,
    auth_origin: String,
}

impl AgentTokenClient {
    pub fn new(auth_origin: &str) -> Self {
        let mut origin = auth_origin.trim().trim_end_matches('/').to_string();
        for suffix in ["/api/v1", "/api/billing"] {
            if origin.to_lowercase().ends_with(suffix) {
                origin = origin[..origin.len() - suffix.len()].trim_end_matches('/').to_string();
                break;
            }
        }
        Self {
            http: Client::builder()
                .user_agent("billing_http/0.1")
                .build()
                .expect("reqwest client"),
            auth_origin: origin,
        }
    }

    pub async fn mint(&self, request: &AgentTokenMintRequest) -> Result<AgentTokenMintResponse> {
        let url = format!("{}/api/auth/agent/token", self.auth_origin);
        let res = self.http.post(url).json(request).send().await?;
        let status = res.status();
        let text = res.text().await?;
        if !status.is_success() {
            return Err(BillingHttpError::Http {
                status: status.as_u16(),
                body: truncate_body(&text),
            });
        }
        let raw: serde_json::Value = serde_json::from_str(&text)?;
        let data = unwrap_data(raw);
        serde_json::from_value(data).map_err(BillingHttpError::from)
    }
}
