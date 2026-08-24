# Bindings

Shared FFI scaffolding for language wrappers over `two-key-core`.

| Binding | Status | Notes |
|---------|--------|-------|
| flutter_rust_bridge | Planned | Dart / Flutter canary (`packages/dart`) |
| UniFFI | Planned | Kotlin + Swift from the same Rust facade (`crate::facade`) |

Do not fork business logic in bindings — only adapt types and async.
