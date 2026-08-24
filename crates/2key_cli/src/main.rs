//! 2key Billing CLI — thin entrypoint over two-key-core.

use std::env;
use std::fs;
use std::process::ExitCode;
use two_key_core::{
    normalize_api_base_url, InMemoryStorage, LicenseVerifier, SdkConfig, SystemClock,
    TwoKeyClient, VerifyOutcome,
};

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
        Some("verify-license") => {
            // two-key verify-license --pem <path> --jwt <path|token>
            let mut pem_path: Option<String> = None;
            let mut jwt_arg: Option<String> = None;
            while let Some(a) = args.next() {
                match a.as_str() {
                    "--pem" => pem_path = args.next(),
                    "--jwt" => jwt_arg = args.next(),
                    other if pem_path.is_none() && !other.starts_with('-') => {
                        pem_path = Some(other.to_string());
                    }
                    other if jwt_arg.is_none() && !other.starts_with('-') => {
                        jwt_arg = Some(other.to_string());
                    }
                    _ => {}
                }
            }
            let Some(pem_path) = pem_path else {
                eprintln!("usage: two-key verify-license --pem <public.pem> --jwt <token-or-file>");
                return ExitCode::FAILURE;
            };
            let Some(jwt_arg) = jwt_arg else {
                eprintln!("usage: two-key verify-license --pem <public.pem> --jwt <token-or-file>");
                return ExitCode::FAILURE;
            };
            let pem = match fs::read_to_string(&pem_path) {
                Ok(s) => s,
                Err(e) => {
                    eprintln!("read pem: {e}");
                    return ExitCode::FAILURE;
                }
            };
            let jwt = if jwt_arg.contains('.') && !std::path::Path::new(&jwt_arg).exists() {
                jwt_arg
            } else {
                match fs::read_to_string(&jwt_arg) {
                    Ok(s) => s.trim().to_string(),
                    Err(_) => jwt_arg,
                }
            };

            let verifier = match LicenseVerifier::from_pem(&pem) {
                Ok(v) => v,
                Err(e) => {
                    eprintln!("{e}");
                    return ExitCode::FAILURE;
                }
            };
            match verifier.verify_and_decode(&jwt, &SystemClock) {
                VerifyOutcome::Success(p) => {
                    println!(
                        "ok paying_party={} subscriptions={}",
                        p.paying_party.id,
                        p.subscriptions.len()
                    );
                    ExitCode::SUCCESS
                }
                VerifyOutcome::Failure { code, message } => {
                    eprintln!("{code}: {message}");
                    ExitCode::FAILURE
                }
            }
        }
        Some("session-demo") => {
            // In-memory session save/load smoke (no network).
            let pem = env::var("TWOKEY_PUBLIC_KEY_PEM").unwrap_or_else(|_| {
                // Minimal placeholder — validate only needs non-empty; verify not called.
                "-----BEGIN PUBLIC KEY-----\nMFkwEwYH\n-----END PUBLIC KEY-----\n".into()
            });
            let cfg = SdkConfig {
                api_base_url: env::var("TWOKEY_API_BASE_URL")
                    .unwrap_or_else(|_| "https://billing.example.com".into()),
                public_key_pem: pem,
                storage_prefix: env::var("TWOKEY_STORAGE_PREFIX")
                    .unwrap_or_else(|_| "two_key_cli".into()),
                portal_base_url: None,
                shop_path: "/shop".into(),
                deep_link_scheme: None,
                license_poll_interval: std::time::Duration::from_secs(6 * 3600),
            };
            // LicenseVerifier::from_pem will fail on placeholder — use client only if PEM valid.
            match TwoKeyClient::new(cfg, InMemoryStorage::new(), SystemClock) {
                Ok(client) => {
                    let mut s = two_key_core::AccountSession::new("demo");
                    s.access_token = Some("demo-token".into());
                    if let Err(e) = client.save_session(&s) {
                        eprintln!("{e}");
                        return ExitCode::FAILURE;
                    }
                    match client.load_session("demo") {
                        Ok(Some(loaded)) => {
                            println!(
                                "ok session account={} token={}",
                                loaded.account_key,
                                loaded.access_token.as_deref().unwrap_or("")
                            );
                            ExitCode::SUCCESS
                        }
                        Ok(None) => {
                            eprintln!("session missing after save");
                            ExitCode::FAILURE
                        }
                        Err(e) => {
                            eprintln!("{e}");
                            ExitCode::FAILURE
                        }
                    }
                }
                Err(e) => {
                    eprintln!("{e}");
                    eprintln!("hint: set TWOKEY_PUBLIC_KEY_PEM to a real EC public key PEM");
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
            eprintln!("  verify-license --pem <public.pem> --jwt <token-or-file>");
            eprintln!("  session-demo   (env PEM + optional API/prefix)");
            ExitCode::SUCCESS
        }
    }
}
