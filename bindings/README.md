# Bindings

Shared FFI scaffolding for language wrappers over `two-key-core`.

| Binding | Status | Notes |
|---------|--------|-------|
| **C ABI + dart:ffi** | **Wired** | `c_api.rs` → `packages/dart` `TwoKeyCoreFfi` / `LicenseBackend.rustCore` |
| flutter_rust_bridge | Target **2.11.x** | Can replace C ABI later; same `ffi_*` surface |
| UniFFI | Planned | Kotlin + Swift |

## C ABI (current)

Build:

```bash
cargo build -p two-key-core
# Windows: target/debug/two_key_core.dll
# Linux:   target/debug/libtwo_key_core.so
# macOS:   target/debug/libtwo_key_core.dylib
```

Exports:

- `two_key_string_free`
- `two_key_normalize_api_base_url`
- `two_key_verify_license_json` (JSON includes `claims` on success)
- `two_key_validate_config_json`
- `two_key_error_codes`

Dart:

```dart
TwoKeyRuntime.licenseBackend = LicenseBackend.rustCore;
// optional: TwoKeyRuntime.nativeLibraryPath = r'...\two_key_core.dll';
// or: set TWOKEY_CORE_LIB
final payload = verifyLicenseJwt(jwt, pem);
```

## flutter_rust_bridge (optional upgrade)

1. Pin **flutter_rust_bridge `^2.11.0`** when migrating off raw C ABI.
2. Prefer wrapping `crate::ffi` / `crate::facade` only.
3. Dual-path flag remains `TwoKeyRuntime.licenseBackend`.
