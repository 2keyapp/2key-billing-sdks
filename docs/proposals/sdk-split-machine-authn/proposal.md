# SDK split: machine-authn HTTP vs core crypto

**Status:** In progress  
**Repos:** `2key-billing-sdks` (public HTTP + flows), `2key-core-sdk` (private crypto)

## Boundary

| Layer | Repo | Owns |
|-------|------|------|
| Crypto | `2key-core-sdk` | CSR, local CA sign, cert verify, mTLS material, JWS/PoP (`dp-rust-mtls`) |
| Billing HTTP | `2key-billing-sdks` | All HTTPS to billing (human + machine + agent) |
| Server | `2key-billing` | `/api/v1/machine-authn/*`, `/api/auth/agent/token` |

Machine enrollment **HTTP** lives in billing-sdks. Device **x.509 / Ed25519** ceremony stays in core-sdk and is exposed to Dart via `two_key_crypto_*` C ABI + `DeviceCrypto`.

## Tasks

- [x] OpenAPI + conformance fixtures + this proposal
- [ ] Dart `MachineAuthnClient` + `AgentTokenClient`
- [ ] Core `two_key_crypto_*` C ABI + lockfile bump
- [ ] Dart `DeviceCrypto` FRB wrapper
- [ ] `MachineEnrollFlow` + `AgentEntitlementFlow` + identity store
- [x] Public `billing_http` crate removed from `2key-billing-sdks` (HTTP is Dart + `@2key/dp-ts`)
- [ ] Move `@2key/dp-ts` machine-authn HTTP to billing-sdks; browser deprecation shim

## Verification

| Gate | Command |
|------|---------|
| Dart unit | `cd packages/dart && flutter test` |
| Core crypto | `cargo test -p two-key-core` |
| No HTTP in core | `machine-authn` only via `billing_http` dep in `dp-rust-sdk` |
