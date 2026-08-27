# SDK split machine-authn — task checklist

1. Contract: `openapi/2key-billing.yaml`, `conformance/fixtures/*`, `docs/architecture.md` §6/§8
2. Dart HTTP: `MachineAuthnClient`, `AgentTokenClient`, unit tests
3. Core crypto: `two_key_crypto_*` in `2key-core-sdk/crates/2key_core`, bump `core-binaries.lock.json`
4. Dart crypto: `DeviceCrypto` + `frb_wire.dart` lookups
5. Dart flows: `device_identity_store`, `MachineEnrollFlow`, `AgentEntitlementFlow`
6. Trim core HTTP: `crates/billing_http`, refactor `dp-rust-sdk` / `dp-cli`
7. Browser TS: `@2key/billing-ts` machine-authn module + browser-sdk re-export shim
