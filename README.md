# 2key-billing-sdks

**Public** monorepo for 2key Billing **native** client distribution (CLI + Dart wrappers).

## Priority: desktop CLI

The primary deliverable for operators and desktop integration is the **`two-key` CLI** on **Windows, macOS, and Linux**.

```bash
# macOS / Linux
./scripts/fetch-binaries.sh
./bin/two-key version

# Windows (PowerShell)
.\scripts\fetch-binaries.ps1
.\bin\two-key.exe version
```

Binaries are built from the **private** [`2key-core-sdk`](https://github.com/2keyapp/2key-core-sdk) repo (Binary Private Core). This public repo does **not** ship `two-key-core` source.

| Component | Path | Role |
|-----------|------|------|
| **CLI install** | `scripts/fetch-binaries.*`, `bin/` | Download pinned `two-key` + optional `libtwo_key_core` |
| **Binary lock** | `core-binaries.lock.json` | Exact version + checksums |
| **2key_dart_sdk** | `packages/dart` | Flutter/Dart SDK (canonical) |
| OpenAPI | `openapi/2key-billing.yaml` | `/api/v1` contract |
| Conformance | `conformance/fixtures` | Shared JWT claim fixtures |

**Browser / TypeScript SDK** moved to [`2key-browser-sdk`](https://github.com/2keyapp/2key-browser-sdk)
(`@2key/browser-sdk` — AuthN + AuthZ + Billing). Do not add a TS product SDK here.

Host apps depend on **`2key_<lang>_sdk` / `@2key/browser-sdk` only** — never on Better Auth or private core source.

## Quick start

```bash
# CLI (recommended)
./scripts/fetch-binaries.sh   # or fetch-binaries.ps1 on Windows
./bin/two-key --help

# Dart SDK
cd packages/dart && dart pub get && dart test

# Browser SDK (separate repo)
# https://github.com/2keyapp/2key-browser-sdk
```

## Docs

- [Architecture (Binary Private Core)](docs/architecture.md)
- [Host integration](docs/host-integration.md)
- [CLI](docs/cli.md)
- [Auth protocol](docs/auth-protocol.md)
- [SDK conformance](docs/sdk-conformance.md)
- [Retire `billing_dart_sdk`](docs/retire-billing-dart-sdk.md)
- Browser portal cutover: [`2key-browser-sdk/docs/portal-migration.md`](https://github.com/2keyapp/2key-browser-sdk/blob/main/docs/portal-migration.md)

## Design north star

**Private `2key-core-sdk` owns native Rust truth and releases binaries; `2key-browser-sdk` owns browser TypeScript truth; this repo distributes the CLI + Dart wrappers; OpenAPI + fixtures own the billing contract.**
