# 2key_dart_sdk (`two_key_dart_sdk`)

Dart / Flutter host-facing SDK for 2key Billing.

**Current:** interim pure-Dart (claim parse, ES256 verify via `dart_jsonwebtoken`, `/api/v1` license client).  
**Next:** flutter_rust_bridge → `crates/2key_core` dual-path; Better Auth stays internal (Phase A).

Host apps depend on **this package only** — never `better_auth` or `two-key-core`.

```yaml
dependencies:
  two_key_dart_sdk:
    path: ../path/to/2key-billing-sdks/packages/dart
```

Production Scomm still uses `billing_dart_sdk` until dual-path cutover.
