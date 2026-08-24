# 2key_dart_sdk (`two_key_dart_sdk`)

Dart / Flutter host-facing SDK for 2key Billing.

**Dual-path license verify:**

| Backend | How |
|---------|-----|
| `LicenseBackend.pureDart` (default) | `dart_jsonwebtoken` |
| `LicenseBackend.rustCore` | `dart:ffi` → `two_key_core` cdylib |

```bash
cargo build -p two-key-core
# optional: export TWOKEY_CORE_LIB=/path/to/libtwo_key_core.so
```

```dart
TwoKeyRuntime.licenseBackend = LicenseBackend.rustCore;
final payload = verifyLicenseJwt(jwt, pem);
```

Host apps depend on **this package only** — never `better_auth` or `two-key-core` crates directly.

Production Scomm still uses `billing_dart_sdk` until dual-path cutover + Better Auth wiring.
