//! 2key Billing CLI — thin entrypoint over two-key-core.

use std::env;
use std::process::ExitCode;
use two_key_core::{normalize_api_base_url, SdkConfig};

fn main() -> ExitCode {
    let mut args = env::args().skip(1);
    match args.next().as_deref() {
        Some("version") => {
            println!("two-key {}", env!("CARGO_PKG_VERSION"));
            ExitCode::SUCCESS
        }
        Some("normalize-url") => {
            let Some(url) = args.next() else {
                eprintln!("usage: two-key normalize-url <url>");
                return ExitCode::FAILURE;
            };
            println!("{}", normalize_api_base_url(&url));
            ExitCode::SUCCESS
        }
        Some("check-config") => {
            let api = env::var("TWOKEY_API_BASE_URL").unwrap_or_default();
            let pem = env::var("TWOKEY_PUBLIC_KEY_PEM").unwrap_or_default();
            let prefix = env::var("TWOKEY_STORAGE_PREFIX").unwrap_or_default();
            let cfg = SdkConfig {
                api_base_url: api,
                public_key_pem: pem,
                storage_prefix: prefix,
                portal_base_url: None,
                shop_path: "/shop".into(),
                deep_link_scheme: None,
                license_poll_interval: std::time::Duration::from_secs(6 * 3600),
            };
            match cfg.validate() {
                Ok(c) => {
                    println!("ok api_base_url={}", c.api_base_url);
                    ExitCode::SUCCESS
                }
                Err(e) => {
                    eprintln!("{e}");
                    ExitCode::FAILURE
                }
            }
        }
        _ => {
            eprintln!("two-key — 2key Billing CLI");
            eprintln!("commands:");
            eprintln!("  version");
            eprintln!("  normalize-url <url>");
            eprintln!("  check-config   (env: TWOKEY_API_BASE_URL, TWOKEY_PUBLIC_KEY_PEM, TWOKEY_STORAGE_PREFIX)");
            ExitCode::SUCCESS
        }
    }
}
