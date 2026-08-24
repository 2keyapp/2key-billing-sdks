# 2key-billing-sdks

Public monorepo for **2key Billing** client SDKs.

| Component | Path | Role |
|-----------|------|------|
| **two-key-core** (`2key_core`) | `crates/2key_core` | Native behavioral reference (Rust) |
| **two-key** CLI | `crates/2key_cli` | Thin CLI over core |
| **@2key/ts-sdk** | `packages/ts` | Browser behavioral reference |
| **2key_dart_sdk** | `packages/dart` | Flutter wrapper (migration in progress) |
| OpenAPI | `openapi/2key-billing.yaml` | `/api/v1` contract |
| Conformance | `conformance/fixtures` | Shared JWT claim fixtures |

Host apps depend on **`2key_<lang>_sdk` only** — never on Better Auth or `two-key-core` directly.

## Quick start

```bash
# Rust core
cargo test -p two-key-core
cargo run -p two-key-cli -- version

# Browser SDK
cd packages/ts && npm install && npm test && npm run build
```

## Docs

- [Architecture](docs/architecture.md)
- [Auth protocol](docs/auth-protocol.md)
- [SDK conformance](docs/sdk-conformance.md)
- [Error codes](docs/error-codes.md)
- [Rust-core proposal](docs/proposals/add-rust-core-sdk/proposal.md)

## Design north star

**Rust owns native billing truth; TypeScript owns browser truth; OpenAPI + fixtures own the contract; wrappers only adapt storage, OAuth chrome, and language idioms.**
