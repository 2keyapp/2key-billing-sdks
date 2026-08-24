# Tasks: add-rust-core-sdk

## 0. Approval gate

- [x] 0.1 Review `proposal.md` and `design.md`
- [x] 0.2 Resolve open questions in `design.md` (FRB versioning, auth Phase B scope, rename timing, crates.io)
  - FRB target: **2.11.x**; Auth Phase A = pasted/env + Dart Better Auth; rename deferred; crates.io git-only until 1.0
- [x] 0.3 Approve this change before any implementation

## 1. Spec lock (protocol)

- [x] 1.1 Export / update `openapi/2key-billing.yaml` for current `/api/v1` (license, subscriptions/me, plans)
- [x] 1.2 Write `docs/auth-protocol.md` (browser cookies vs native deep-link/loopback)
- [x] 1.3 Extract conformance fixtures from Dart tests (ES256 JWTs, ETag 200/304, entitlement claim names)
- [x] 1.4 Document shared error code list

## 2. Rust core (`2key_core`)

- [x] 2.1 Scaffold crate (workspace under `2key-billing-sdks`)
- [x] 2.2 Config types — required `api_base_url`, public PEM, `storage_prefix`; no brand defaults
- [x] 2.3 Storage + Auth + Clock traits (ports) — Storage + Clock (Auth remains wrapper Phase A)
- [x] 2.4 License JWT verify/decode (ES256) matching Dart payload fields
- [x] 2.5 HTTP client for license sync (ETag / 304), subscriptions/me, plans
- [x] 2.6 Session orchestration — persist, restore, clear, sync, poll policy
- [x] 2.7 Typed errors + mapping table for wrappers
- [x] 2.8 Rust unit tests against conformance fixtures

## 3. Bindings facade

- [x] 3.1 Define stable Rust facade module intended for FFI (`facade::TwoKeyClient`)
- [x] 3.1b JSON/string `ffi::*` helpers for FRB/UniFFI (`ffi_verify_license_json`, …)
- [x] 3.1c C ABI (`c_api.rs`) + `cdylib` crate type
- [x] 3.2 Pin FRB target **2.11.x**; interim **dart:ffi** wired to C ABI
- [ ] 3.3 (Later) UniFFI scaffolding for Kotlin/Swift from same facade
- [x] 3.4 CI builds `two-key-core` cdylib before Dart FFI tests

## 4. Dart wrapper (canary)

- [x] 4.0 Scaffold `packages/dart` (`two_key_dart_sdk`) with fixture-aligned verify + API client
- [x] 4.0b Session manager + portal helpers + `LicenseBackend` dual-path flag
- [x] 4.1 Wire `rustCore` path via dart:ffi → C ABI (`TwoKeyCoreFfi`)
- [ ] 4.2 Map existing public surface (`BillingSdkConfig`, session, license sync) onto facade
- [ ] 4.3 Keep Better Auth Dart client internal for Phase A token mint
- [ ] 4.4 Host still supplies `AuthSessionLauncher` + storage
- [ ] 4.5 Conformance + integration tests green on Rust path (license JWT roundtrip via FFI)
- [ ] 4.6 Scomm/secMail optional canary pin; soak; then default Rust path
- [ ] 4.7 Remove duplicate pure-Dart license/session code after soak

## 5. CLI

- [x] 5.1 `2key_cli` binary on `2key_core` (stub: version / normalize-url / check-config)
- [x] 5.1b `verify-license` + `session-demo` commands
- [x] 5.2 Headless auth adapter (pasted / env token via `StaticTokenAuth` + `auth-token`)
- [x] 5.3 OS keyring storage adapter (`KeyringStorage`, `TWOKEY_USE_KEYRING=1`)
- [x] 5.4 `sync-license` command (staging smoke when env credentials set)

## 6. Browser SDK (`@2key/ts-sdk`)

- [x] 6.1 Scaffold package with hand-maintained `/api/v1` client + claim parser
- [x] 6.2 Auth helpers (`authBaseUrl`, `socialSignInUrl` — host does redirect/cookie)
- [x] 6.3 License verify via Web Crypto; same claim names as fixtures
- [x] 6.4 Session helpers + portal/shop URL helpers
- [x] 6.5 Conformance suite in CI (fixture + ES256 roundtrip)
- [ ] 6.6 Migrate billing-portal to `@2key/ts-sdk` (when ready)

## 7. Monorepo & naming

- [x] 7.1 Create / migrate to `2key-billing-sdks` layout per design
- [x] 7.2a Scaffold `packages/dart` as `two_key_dart_sdk` (interim pure-Dart; FRB later)
- [ ] 7.2 Rename production `billing_dart_sdk` → cut over to monorepo package
- [x] 7.3 Update parent architecture doc status to Adopted for Rust-core sections
- [ ] 7.4 App docs: hosts depend on `2key_<lang>_sdk` only

## 8. Later languages / M2M

- [ ] 8.1 UniFFI Kotlin SDK
- [ ] 8.2 UniFFI Swift SDK
- [ ] 8.3 Usage event APIs in core + wrappers when server ships
- [ ] 8.4 mTLS / machine-token helpers in CLI / node first
