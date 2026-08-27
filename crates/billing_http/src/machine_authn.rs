use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION, CONTENT_TYPE, USER_AGENT};
use reqwest::{Client, Method};
use serde::de::DeserializeOwned;
use serde::Serialize;

use crate::error::{truncate_body, unwrap_data, BillingHttpError, Result};

const PLUGIN: &str = "machine-authn";

/// Billing API v1 Machine AuthN HTTP client.
pub struct MachineAuthnClient {
    http: Client,
    base_url: String,
    auth_token: Option<String>,
    extra_headers: HeaderMap,
}

impl MachineAuthnClient {
    pub fn new(base_url: &str) -> Self {
        let http = Client::builder()
            .user_agent("billing_http/0.1")
            .build()
            .expect("reqwest client");
        Self {
            http,
            base_url: base_url.trim_end_matches('/').to_string(),
            auth_token: None,
            extra_headers: HeaderMap::new(),
        }
    }

    pub fn with_auth(mut self, token: impl Into<String>) -> Self {
        self.auth_token = Some(token.into());
        self
    }

    pub fn with_extra_headers(mut self, headers: HeaderMap) -> Self {
        self.extra_headers = headers;
        self
    }

    pub fn base_url(&self) -> &str {
        &self.base_url
    }

    fn url(&self, path: &str) -> String {
        format!("{}/{}", self.base_url.trim_end_matches('/'), path.trim_start_matches('/'))
    }

    fn plugin_path(&self, name: &str) -> String {
        format!("{PLUGIN}/{name}")
    }

    fn headers(&self, with_auth: bool) -> Result<HeaderMap> {
        let mut headers = self.extra_headers.clone();
        headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
        headers.insert(USER_AGENT, HeaderValue::from_static("billing_http/0.1"));
        if with_auth {
            if let Some(token) = &self.auth_token {
                let value = if token.contains(' ') {
                    token.clone()
                } else {
                    format!("Bearer {token}")
                };
                headers.insert(
                    AUTHORIZATION,
                    HeaderValue::from_str(&value)
                        .map_err(|e| BillingHttpError::Message(format!("invalid auth: {e}")))?,
                );
            }
        }
        Ok(headers)
    }

    async fn send_json<B: Serialize, T: DeserializeOwned>(
        &self,
        method: Method,
        path: &str,
        query: &[(&str, &str)],
        body: Option<&B>,
        with_auth: bool,
    ) -> Result<T> {
        let url = self.url(path);
        let mut req = self.http.request(method, &url).headers(self.headers(with_auth)?);
        if !query.is_empty() {
            req = req.query(query);
        }
        if let Some(body) = body {
            req = req.json(body);
        }
        let res = req.send().await?;
        let status = res.status();
        let text = res.text().await?;
        if !status.is_success() {
            return Err(BillingHttpError::Http {
                status: status.as_u16(),
                body: truncate_body(&text),
            });
        }
        if text.trim().is_empty() {
            return Ok(serde_json::from_value(serde_json::Value::Null)?);
        }
        let raw: serde_json::Value = serde_json::from_str(&text)?;
        let data = unwrap_data(raw);
        serde_json::from_value(data).map_err(BillingHttpError::from)
    }

    pub async fn register<B: Serialize, T: DeserializeOwned>(&self, body: &B) -> Result<T> {
        self.send_json(
            Method::POST,
            &self.plugin_path("register"),
            &[],
            Some(body),
            true,
        )
        .await
    }

    pub async fn enroll_create<B: Serialize, T: DeserializeOwned>(&self, body: &B) -> Result<T> {
        self.send_json(
            Method::POST,
            &self.plugin_path("enroll-create"),
            &[],
            Some(body),
            true,
        )
        .await
    }

    pub async fn enroll_approve<B: Serialize, T: DeserializeOwned>(&self, body: &B) -> Result<T> {
        self.send_json(
            Method::POST,
            &self.plugin_path("enroll-approve"),
            &[],
            Some(body),
            true,
        )
        .await
    }

    pub async fn enroll_pull<B: Serialize, T: DeserializeOwned>(&self, body: &B) -> Result<T> {
        self.send_json(
            Method::POST,
            &self.plugin_path("enroll-pull"),
            &[],
            Some(body),
            false,
        )
        .await
    }

    pub async fn enroll_invite_create<B: Serialize, T: DeserializeOwned>(
        &self,
        body: &B,
    ) -> Result<T> {
        self.send_json(
            Method::POST,
            &self.plugin_path("enroll-invite"),
            &[],
            Some(body),
            true,
        )
        .await
    }

    pub async fn get_enroll_invite<T: DeserializeOwned>(
        &self,
        paying_party_id: &str,
        invite_token: &str,
    ) -> Result<T> {
        self.send_json(
            Method::GET,
            &self.plugin_path("enroll-invite"),
            &[
                ("payingPartyId", paying_party_id),
                ("inviteToken", invite_token),
            ],
            None::<&()>,
            false,
        )
        .await
    }

    pub async fn issue_delegate<B: Serialize, T: DeserializeOwned>(&self, body: &B) -> Result<T> {
        self.send_json(
            Method::POST,
            &self.plugin_path("issue-delegate"),
            &[],
            Some(body),
            true,
        )
        .await
    }

    pub async fn assert_subset<B: Serialize, T: DeserializeOwned>(&self, body: &B) -> Result<T> {
        self.send_json(
            Method::POST,
            &self.plugin_path("assert-subset"),
            &[],
            Some(body),
            true,
        )
        .await
    }

    pub async fn platform_root<T: DeserializeOwned>(&self) -> Result<T> {
        self.send_json(
            Method::GET,
            &self.plugin_path("platform-root"),
            &[],
            None::<&()>,
            false,
        )
        .await
    }

    pub async fn credential_status<T: DeserializeOwned>(&self, ski: &str) -> Result<T> {
        self.send_json(
            Method::GET,
            &self.plugin_path("credential-status"),
            &[("ski", ski)],
            None::<&()>,
            true,
        )
        .await
    }

    /// Forward-compatible SDK route (may 404 on older servers).
    pub async fn enroll_list<T: DeserializeOwned>(
        &self,
        entity_id: &str,
        status: Option<&str>,
    ) -> Result<T> {
        let mut query = vec![("entityId", entity_id)];
        if let Some(status) = status.filter(|s| !s.is_empty()) {
            query.push(("status", status));
        }
        self.send_json(
            Method::GET,
            &self.plugin_path("enroll-list"),
            &query,
            None::<&()>,
            true,
        )
        .await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use wiremock::matchers::{method, path};
    use wiremock::{Mock, MockServer, ResponseTemplate};

    #[tokio::test]
    async fn enroll_create_hits_machine_authn_path() {
        let server = MockServer::start().await;
        Mock::given(method("POST"))
            .and(path("/machine-authn/enroll-create"))
            .respond_with(ResponseTemplate::new(201).set_body_json(json!({
                "data": {
                    "enrollId": "id-1",
                    "pullToken": "ptok",
                    "subjectSki": "ski",
                    "status": "pending"
                }
            })))
            .mount(&server)
            .await;

        let client = MachineAuthnClient::new(&server.uri()).with_auth("token");
        let body = json!({"payingPartyId": "1", "memberId": "m", "csrPem": "csr"});
        let resp: serde_json::Value = client.enroll_create(&body).await.unwrap();
        assert_eq!(resp["pullToken"], "ptok");
    }
}
