//! HTTP client for billing `/api/v1/machine-authn/*` and `/api/auth/agent/token`.
//!
//! Lives in public **2key-billing-sdks**; private `dp-rust-sdk` delegates here.

mod agent;
mod error;
mod machine_authn;

pub use agent::{AgentTokenClient, AgentTokenMintRequest, AgentTokenMintResponse};
pub use error::{BillingHttpError, Result};
pub use machine_authn::MachineAuthnClient;
