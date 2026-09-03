# 2key SDKs

Public using-party SDKs for 2key Billing. One repo, one OpenAPI, one fixture set, one CI — language clients stay in lockstep.

Hosts import **only** the package for their runtime. Never Better Auth, never private `two-key-core` source.

## Languages

| Runtime | Package | Path | Registry |
|---------|---------|------|----------|
| Flutter / Dart | `two_key_dart_sdk` | [`packages/dart`](packages/dart/) | pub (git until published) |
| Browser / Node | `@2key/browser-sdk` | [`packages/javascript/packages/browser-sdk`](packages/javascript/packages/browser-sdk/) | npm (workspace until published) |
| Desktop CLI | `two-key` | [`scripts/fetch-binaries.*`](scripts/) | GitHub Release assets |

Later language roots: `packages/kotlin`, `packages/swift`, `packages/python`. Each consumes `openapi/` + `conformance/`. Do not add a second OpenAPI copy.

## Layout

```
.
├── openapi/                      # /api/v1 contract (single source)
├── conformance/                  # license JWT + AuthZ + machine-authn vectors
├── packages/
│   ├── dart/                     # 2key_dart_sdk (FFI → two-key-core binaries)
│   └── javascript/               # pnpm workspace (never includes dart)
│       ├── packages/             # @2key/browser-sdk, @2key/dp-*
│       └── catalogs/             # @2key/catalog-* tenant seeds
├── scripts/                      # fetch pinned CLI + native libs
└── bindings/                     # UniFFI notes (Kotlin / Swift later)
```

pnpm’s workspace file lives **inside** `packages/javascript`, so it cannot pick up Dart. Flutter git path stays `packages/dart`. Shared truth stays at the repo root.

Rust core source is **not** in this repo. Fetch binaries; see [`crates/README.md`](crates/README.md).

## Shared contract

A change to a claim name, error code, or `/api/v1` path is **one PR**. CI runs Dart and JavaScript on every change. Both must pass.

| Artifact | Role |
|----------|------|
| [`openapi/2key-billing.yaml`](openapi/2key-billing.yaml) | HTTP contract |
| [`conformance/fixtures/`](conformance/fixtures/) | License JWT claims (v1 + v3), machine enroll, agent token |
| [`conformance/dp-authz/`](conformance/dp-authz/) | AuthZ authorize / subset vectors |
| [`docs/error-codes.md`](docs/error-codes.md) | Stable snake_case codes |

Runtimes stay different: Dart is FFI to `two-key-core`; JavaScript is TypeScript + Web Crypto. They share fixtures and names, not binaries.

## Develop

```bash
# All language suites (requires Flutter + pnpm 9 + Node 20+)
make test

# Dart / Flutter
cd packages/dart && flutter pub get && flutter test

# JavaScript / TypeScript
cd packages/javascript && pnpm install && pnpm run ci

# CLI binaries (from private 2key-core-sdk releases)
./scripts/fetch-binaries.sh   # or fetch-binaries.ps1 on Windows
./bin/two-key --help
```

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Hosts

```yaml
# Flutter
dependencies:
  two_key_dart_sdk:
    git:
      url: https://github.com/2keyapp/2key-billing-sdks.git
      path: packages/dart
      ref: <PINNED_SHA>
```

```bash
# Browser (when published)
pnpm add @2key/browser-sdk

# Until npm publish — pnpm git subdirectory
pnpm add github:2keyapp/2key-billing-sdks#path:packages/javascript/packages/browser-sdk
```

```ts
import { acquireApiToken, verifyLicenseJwt, authorize } from "@2key/browser-sdk";
```

Outlook add-in: [docs/office-add-in-embed.md](docs/office-add-in-embed.md). Portal: [docs/portal-migration.md](docs/portal-migration.md).

## Related repos (not this tree)

| Repo | Role |
|------|------|
| `2keyapp/2key-billing` | Private Auth + Billing server |
| `2keyapp/2key-core-sdk` | Private Rust core + CLI source; this repo fetches binaries |
| `2keyapp/better-auth` | Auth engine fork — not a product SDK |

The former `2key-browser-sdk` repo is merged here (`packages/javascript/`). Do not add TypeScript packages anywhere else.

## Docs

- [Architecture](docs/architecture.md)
- [Host integration](docs/host-integration.md)
- [Auth protocol](docs/auth-protocol.md)
- [SDK conformance](docs/sdk-conformance.md)
- [CLI](docs/cli.md)
- [DP AuthZ](docs/DP-AUTHZ.md)
