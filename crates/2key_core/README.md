# two-key-core (`2key_core`)

Native **behavioral reference** for 2key Billing client SDKs.

- License JWT verify (ES256) + entitlement decode
- `/api/v1` HTTP (license ETag/304, subscriptions/me, plans)
- Session orchestration over injected storage ports
- Shared error codes for language wrappers

Host apps must **not** depend on this crate directly — use `2key_dart_sdk`, `2key_cli`, etc.

See repo docs: `docs/architecture.md`, `docs/sdk-conformance.md`.
