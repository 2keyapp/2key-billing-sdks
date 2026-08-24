# Bindings

Shared FFI scaffolding for language wrappers over `two-key-core`.

| Binding | Status | Notes |
|---------|--------|-------|
| flutter_rust_bridge | **Pinned target: 2.11.x** | Use JSON/string helpers in `two_key_core::ffi` first |
| UniFFI | Planned | Kotlin + Swift from the same facade |

## flutter_rust_bridge (next implementation step)

1. Pin **flutter_rust_bridge `^2.11.0`** in the Dart package when wiring begins.
2. Expose only `crate::ffi` + `crate::facade` — do not bind internal modules.
3. Suggested first FRB surface (already available as plain Rust):
   - `ffi_normalize_api_base_url`
   - `ffi_verify_license_json`
   - `ffi_validate_config_json`
   - `ffi_error_codes`
4. Dual-path flag in Dart: `TwoKeyRuntime.licenseBackend` (`pureDart` \| `rustCore`).

```bash
# After FRB codegen is added:
cargo build -p two-key-core
# generate Dart under packages/dart/lib/src/frb/
```

Do not fork business logic in bindings — only adapt types and async.
