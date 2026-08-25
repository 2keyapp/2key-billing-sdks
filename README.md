# 2key-billing-sdks

**Public** monorepo for 2key Billing client distribution.

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
| **@2key/ts-sdk** | `packages/ts` | Browser SDK (protocol parity) |
| **2key_dart_sdk** | `packages/dart` | Flutter/Dart SDK (canonical; replaces `billing_dart_sdk`) |
| OpenAPI | `openapi/2key-billing.yaml` | `/api/v1` contract |
| Conformance | `conformance/fixtures` | Shared JWT claim fixtures |

Host apps depend on **`2key_<lang>_sdk` only** — never on Better Auth or private core source.

## Quick start

```bash
# CLI (recommended)
./scripts/fetch-binaries.sh   # or fetch-binaries.ps1 on Windows
./bin/two-key --help

# Browser SDK
cd packages/ts && npm install && npm test && npm run build

# Dart SDK
cd packages/dart && dart pub get && dart test
```

## Docs

- [Architecture (Binary Private Core)](docs/architecture.md)
- [CLI](docs/cli.md)
- [Auth protocol](docs/auth-protocol.md)
- [SDK conformance](docs/sdk-conformance.md)
- [Retire `billing_dart_sdk`](docs/retire-billing-dart-sdk.md)

## Design north star

**Private `2key-core-sdk` owns native truth and releases binaries; this repo distributes the CLI + language wrappers; TypeScript owns browser truth; OpenAPI + fixtures own the contract.**
