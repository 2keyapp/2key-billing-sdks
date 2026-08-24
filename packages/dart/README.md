# 2key_dart_sdk (migration)

**Status:** Not yet relocated. Production code still lives in  
[`billing_dart_sdk`](https://github.com/2keyapp/billing_dart_sdk) (or your org mirror).

## Target layout

```
packages/dart/   → pub package name `2key_dart_sdk`
                 → flutter_rust_bridge → crates/2key_core (two-key-core)
                 → Better Auth Dart client remains internal (Phase A)
```

## Host apps

Depend on **`2key_dart_sdk` only** — never `better_auth` or `two-key-core` directly.

## Next steps

1. Dual-path in current `billing_dart_sdk` (pure Dart vs Rust) behind a flag  
2. Move package into this folder and rename to `2key_dart_sdk`  
3. Point Scomm/secMail at the git path here  

See `docs/proposals/add-rust-core-sdk/tasks.md` §4.
