# FRB wire (`lib/src/frb`)

Dart product path to private **`two-key-core`**.

| File | Role |
|------|------|
| `billing_mode.dart` | `BillingMode.offline` / `.online` |
| `frb_wire.dart` | C ABI loader (`two_key_*`) — interim until codegen |
| `rust_billing_core.dart` | Sole license verify/sync/bootstrap adapter |

## flutter_rust_bridge 2.13.0

- Pub dependency pinned in `packages/dart/pubspec.yaml`.
- Codegen config lives in private `2key-core-sdk/flutter_rust_bridge.yaml` + `docs/FRB.md`.
- When generated Dart is vendorable, place it under `generated/` and thin-wrap here.

## Offline / online

- **Offline:** `RustBillingCore.verifyLicense` / `initLicense` (no network).
- **Online:** `ensureBillingContextRaw` + `syncLicense` (ETag).

Host storage stays in Dart; session JSON crosses the bridge. There is no pure-Dart
license verify/sync fallback — the native library is required.
