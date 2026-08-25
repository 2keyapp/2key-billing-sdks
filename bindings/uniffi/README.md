# UniFFI bindings (Phase 7 scaffold)

Kotlin and Swift SDKs will consume the same **Binary Private Core** facade as
Dart (`two-key-core` C ABI / facade module) via **UniFFI**.

## Layout (target)

```
bindings/uniffi/          # this folder — IDL + generate scripts (public)
packages/kotlin/          # 2key_kotlin_sdk (later)
packages/swift/           # 2key_swift_sdk (later)
```

Private source of truth remains in **`2key-core-sdk`**:

- `crates/2key_core/src/facade.rs` — stable Rust API
- Future: `crates/2key_core/src/uniffi.udl` (or proc-macro) checked into the
  **private** repo; generated Kotlin/Swift stubs may be vendored here after
  release builds.

## Rules

1. Do **not** put `two-key-core` Rust source in this public monorepo.
2. Generate bindings against a **pinned** core binary / ABI version
   (`core-binaries.lock.json`).
3. Conformance fixtures in `conformance/fixtures` must pass on JVM and Swift
   before calling a language GA.

## Status

| Item | Status |
|------|--------|
| C ABI (`c_api`) | Shipped in private core |
| Dart interim `dart:ffi` | Shipped in `packages/dart` |
| UniFFI IDL | **Scaffold only** — see `2key-core-sdk` `docs/` when added |
| `2key_kotlin_sdk` / `2key_swift_sdk` | Not started (tasks 8.1–8.2) |

When implementing: add UniFFI to private `two-key-core`, publish artifacts,
then add thin packages under `packages/kotlin` and `packages/swift` that load
fetched libs — mirror the Dart pattern.
