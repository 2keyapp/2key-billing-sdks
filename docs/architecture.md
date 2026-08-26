# 2key Billing — Multi-SDK Architecture & Repository Plan

**Status:** Adopted — **Binary Private Core**  
**Private native core:** [`2keyapp/2key-core-sdk`](https://github.com/2keyapp/2key-core-sdk) (`two-key-core` + `two-key` CLI source)  
**Public distribution:** this monorepo — **CLI first** (Win/macOS/Linux) + language wrappers + OpenAPI  
**Browser reference:** public [`2key-browser-sdk`](https://github.com/2keyapp/2key-browser-sdk) (`@2key/browser-sdk`)  
**Dart:** **`packages/dart` / `2key_dart_sdk`** (canonical); `billing_dart_sdk` **retired early** — see [retire-billing-dart-sdk.md](retire-billing-dart-sdk.md)  
**Last updated:** 2026-08-25  
**Repo:** this monorepo (`2key-billing-sdks`)  

---

## 1. Purpose

This document defines how 2key Billing is structured across repositories so that:

1. **Better Auth** stays a continuously syncable upstream fork (auth engine only).
2. **2key Billing server** stays a **private** product (license, usage, mTLS M2M, entitlements, etc.).
3. **Public SDKs** exist per language, named consistently as **`2key_<lang>_sdk`**.
4. **Native behavioral core** (`two-key-core`) lives in **private `2key-core-sdk`** and is distributed as **versioned binaries only** (Binary Private Core).
5. **Desktop CLI** (`two-key`) on Windows / macOS / Linux is the **primary** public native deliverable from this repo (via `scripts/fetch-binaries.*`).
6. **Browser clients** use a first-class **TypeScript SDK** with the same OpenAPI + conformance fixtures (not a WASM wrapper of Rust as the product API).

---

## 2. Naming conventions

### 2.1 Product vs auth engine

| Term | Meaning |
|------|---------|
| **2key Billing** | Product: APIs, license JWTs, usage metering, mTLS M2M, plans, entitlements, portal |
| **Better Auth** | Auth engine (fork). Not the product brand in SDKs or end-user docs |
| **@2key/auth-native** | Server-side Better Auth plugin for native clients (replaces `@better-auth/flutter` naming) |

### 2.2 Public SDK package names

| Language / runtime | Package name | Registry |
|--------------------|--------------|----------|
| Rust core (native reference) | **`two-key-core`** | **Private** `2key-core-sdk` — binaries only to ISVs |
| CLI | **`two-key`** | GitHub Release assets (Win/macOS/Linux) via fetch scripts |
| Dart / Flutter | **`2key_dart_sdk`** (FFI → prebuilt core) | pub (or git until published) |
| TypeScript (browser) | **`@2key/browser-sdk`** | npm — repo `2key-browser-sdk` |
| TypeScript React helpers (optional) | **`2key_react_sdk`** / `@2key/react-sdk` | npm |
| Kotlin (Android / JVM) | **`2key_kotlin_sdk`** (UniFFI → `2key_core`) | Maven |
| Swift (iOS / macOS) | **`2key_swift_sdk`** (UniFFI → `2key_core`) | SPM |
| Python | **`2key_python_sdk`** | PyPI |
| Node server (service / M2M helpers) | **`2key_node_sdk`** / `@2key/node-sdk` | npm |
| C# (later) | **`2key_dotnet_sdk`** | NuGet |
| Go (later) | **`2key_go_sdk`** | module |

**Rule:** Always `2key_<lang>_sdk` for host-facing packages. Never `billing_*` or `better_auth_*` as the public product package name. Apps never depend on `2key_core` directly.

### 2.3 Private packages / repos (never published as ISV source)

| Package / repo | Role |
|----------------|------|
| **`2keyapp/2key-core-sdk`** | Private core: `two-key-core`, `two-key` CLI source, DP **Rust** (`dp-rust*`) |
| **`2keyapp/2key-browser-sdk`** | Public TypeScript / browser SDK: AuthN + AuthZ + Billing + catalogs |
| `@2key/billing-core` | License, usage, plans, seats, pricing, entitlement rules (server) |
| `@2key/billing-mtls` | CA, cert issue/rotate, mTLS verify, machine identities |
| `@2key/billing-api` | HTTP app mounting `/api/v1` |
| `@2key/billing-auth-host` | Better Auth wiring + hooks into billing-core |

### 2.4 Rename map (current → target)

| Current | Target |
|---------|--------|
| `billing_dart_sdk` | **`2key_dart_sdk`** |
| `BillingAuthClient`, `BillingSession`, `BillingSdk` | Keep names initially for compatibility **or** alias under `TwoKey*` with deprecation period (decide in Phase 1) |
| `@better-auth/flutter` | **`@2key/auth-native`** (`packages/native`; deprecated shim `packages/flutter`) |
| `packages/flutter/dart` (`better_auth`) | **`packages/clients/dart`** — still low-level; **not** imported by host apps |
| secMail / Scomm dep `billing_dart_sdk` | `2key_dart_sdk` |

---

## 3. Goals and non-goals

### 3.1 Goals

- Continuous sync of `2keyapp/better-auth` from upstream `better-auth/better-auth`.
- Rapid product development (usage-based billing, mTLS M2M, etc.) **without** blocking on upstream merges.
- One **native behavioral core** in private **`2key-core-sdk`**, released as binaries; **CLI-first** public distribution.
- Private IP in server + core source; public SDKs are wrappers + OpenAPI + fetched binaries.
- Host apps (e.g. Scomm / secMail) depend on **`2key_dart_sdk` only** — never on `better_auth` or core source.
- Early retirement of **`billing_dart_sdk`** in favor of `packages/dart`.

### 3.2 Non-goals

- Turning Better Auth into “2key Billing” by forking large product features into the auth repo.
- Publishing private billing-core or **`two-key-core` source** to npm/pub/crates.io for ISVs.
- Shipping `two-key-core` Rust source inside this public monorepo.
- Using WASM/`2key_core` as the **product** browser API (optional JWT-verify WASM later is fine).
- Requiring every language to reimplement proprietary metering logic client-side.
- Replacing Better Auth with a Rust auth engine on day one.
- Keeping a separate repo named **`dp-sdk`** — that name is retired; use **`2key-core-sdk`**.

---

## 4. High-level architecture

```
┌──────────────────────────────────────────────────────────────────┐
│ PUBLIC CLIENTS                                                   │
│  Scomm (2key_dart_sdk) · CLI · Portal (2key_ts_sdk) · natives   │
└────────────────────────────┬─────────────────────────────────────┘
                             │ HTTPS
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│ PRIVATE: 2key-billing-server                                     │
│  /api/v1/*  (license, usage, plans, mTLS admin, subscriptions)   │
│  /api/auth/* (Better Auth host + @2key/auth-native)              │
│  @2key/billing-core · @2key/billing-mtls                         │
└────────────────────────────┬─────────────────────────────────────┘
                             │ depends on (pinned SHA / release branch)
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│ PUBLIC FORK: 2keyapp/better-auth                                 │
│  upstream sync · native plugin · low-level auth clients          │
└──────────────────────────────────────────────────────────────────┘
```

```mermaid
flowchart TB
  subgraph public_clients["Public client apps"]
    Scomm["Scomm / secMail\n(2key_dart_sdk)"]
    Cli["2key_cli"]
    Portal["Billing portal\n(2key_ts_sdk)"]
    Future["Future apps\n(Kotlin / Swift / …)"]
  end

  subgraph public_sdks["Public: 2key-billing-sdks"]
    Core["crates/2key_core ★ NATIVE REF"]
    DartSDK["packages/dart\n2key_dart_sdk FRB"]
    BrowserSDK["packages/ts\n2key_ts_sdk ★ BROWSER REF"]
    OpenAPI["openapi/\n2key-billing.yaml"]
    Fixtures["conformance/fixtures"]
  end

  subgraph private_server["Private: 2key-billing-server"]
    API["/api/v1/*"]
    AuthHost["/api/auth/*"]
    CorePkg["@2key/billing-core"]
    MTLS["@2key/billing-mtls"]
  end

  subgraph auth_fork["Public fork: 2keyapp/better-auth"]
    BA["better-auth core"]
    NativePlugin["@2key/auth-native"]
  end

  Scomm --> DartSDK
  DartSDK --> Core
  Cli --> Core
  Future --> Core
  Portal --> BrowserSDK
  Core --> OpenAPI
  BrowserSDK --> OpenAPI
  Core --> Fixtures
  BrowserSDK --> Fixtures

  DartSDK --> AuthHost
  BrowserSDK --> AuthHost
  Core --> API
  BrowserSDK --> API

  AuthHost --> BA
  AuthHost --> NativePlugin
  API --> CorePkg
  API --> MTLS
  AuthHost --> CorePkg
  CorePkg --> BA
```

### 4.1 Dependency rules (hard)

| From → To | Allowed? |
|-----------|----------|
| Public SDK → billing-server | HTTPS only |
| Language wrapper → `two-key-core` **binary** | Yes (native path; via fetch / `TWOKEY_CORE_LIB`) |
| Host app → core source / Better Auth | **No** |
| Public SDK → better-auth client | Yes, **inside SDK only**; not re-exported to apps |
| Public SDK → `@2key/billing-core` | **No** |
| Browser SDK → `two-key-core` / WASM as product API | **No** (protocol parity only) |
| billing-server → better-auth fork | Yes |
| better-auth fork → billing-server | **No** |
| Public SDK repo → private core **source** | **No** (binaries + OpenAPI + fixtures only) |
| Public SDK repo → private `2key-core-sdk` Releases | Yes (authenticated fetch) |

---

## 5. Repository layout

### 5.1 Recommended repos

```
2keyapp/better-auth                 # PUBLIC fork — sync heavy, change light
2keyapp/2key-billing                # PRIVATE — Auth+Billing server
2keyapp/2key-core-sdk               # PRIVATE — two-key-core + two-key CLI source + DP
2keyapp/2key-billing-sdks           # PUBLIC — CLI fetch + wrappers + OpenAPI (no core source)
2keyapp/billing-portal              # PRIVATE (or restricted) — uses 2key_ts_sdk
scomm-ai/secMail0                   # PRIVATE app — uses 2key_dart_sdk
```

> **`dp-sdk` is not a repo name.** Delegate Permissions packages live under **`2key-core-sdk`**.

### 5.2 `2keyapp/better-auth` (fork)

```
better-auth/
├── packages/
│   ├── better-auth/                 # upstream core — MINIMAL diffs
│   ├── native/                      # @2key/auth-native (was flutter plugin)
│   └── clients/
│       └── dart/                    # better_auth pub package (low-level)
├── .github/workflows/
│   └── upstream-sync.yml            # merge upstream, test, notify
└── docs/integrations/native-client.md
```

**Allowed in this repo:**

- Upstream merges and conflict resolution.
- Native-client auth: deep links, loopback `?cookie=`, origin headers / trusted origins, session handoff hooks that are **auth-transport** only.
- Low-level Dart (and later Kotlin/Swift) **auth** clients if kept with the fork.
- Product-neutral `delegate-permissions` hooks (`seatBinder`, etc.).

**Forbidden in this repo:**

- Usage meters, invoices, pricing.
- License JWT signing / business rules.
- mTLS CA / machine billing identity product logic.
- Plan catalog, seats, entitlements engines.

### 5.3 `2keyapp/2key-billing` (private server)

```
2key-billing/
├── src/                             # Express Auth+Billing host (evolving → packages/)
├── db/                              # DDP migrations
└── ...
```

Target package split: `billing-core`, `billing-mtls`, `billing-api`, `billing-auth-host`.

### 5.4 `2keyapp/2key-core-sdk` (private core)

```
2key-core-sdk/
├── crates/
│   ├── 2key_core/                   # two-key-core — Binary Private Core source
│   └── 2key_cli/                    # two-key desktop CLI
├── packages/                        # @2key/dp-* Delegate Permissions
├── catalogs/                        # @2key/catalog-*
├── conformance/fixtures/            # shared with public copy
└── .github/workflows/release-binaries.yml
```

### 5.5 `2keyapp/2key-billing-sdks` (public monorepo)

```
2key-billing-sdks/
├── scripts/fetch-binaries.*         # ★ CLI install (Win/macOS/Linux)
├── core-binaries.lock.json          # pinned tag + checksums
├── bin/                             # gitignored fetched binaries
├── openapi/2key-billing.yaml
├── docs/cli.md
├── crates/README.md                 # points at private core (no source)
├── packages/
│   ├── dart/                        # 2key_dart_sdk (canonical; billing_dart_sdk retired)
│   └── ts/                          # 2key_ts_sdk
└── conformance/fixtures/
```

**Migration:** `billing_dart_sdk` → `packages/dart` — see [retire-billing-dart-sdk.md](retire-billing-dart-sdk.md).

---

## 6. Native reference: `2key_core` (+ Dart wrapper)

### 6.1 Role

- **`2key_core` (Rust)** is the **native behavioral reference**: license verify/sync, session orchestration, errors, poll policy.
- **`2key_ts_sdk`** is the **browser behavioral reference** (same OpenAPI + fixtures; cookie/redirect auth).
- **`2key_dart_sdk`** is the **first production wrapper** (FRB) and Scomm/secMail **integration canary**. Until Rust parity is proven, Dart remains the interim reference for claim names and flows extracted into fixtures.

Dart remains valuable because:

- It is production-proven in Scomm / secMail.
- Hardest platform cases (desktop loopback, mobile deep links) are already solved in the Dart auth adapter.
- Dual-path migration (pure Dart → Rust) reduces cutover risk.

### 6.2 Current code map (`billing_dart_sdk` → core / wrapper)

| Current module | Responsibility | Lands in |
|----------------|----------------|----------|
| `BillingAuthClient` | Identity: social/email, session, API JWT mint, portal handoff | Wrapper auth adapter (Phase A Dart Better Auth; ports into core session) |
| `SecureBillingAuthStorage` | Persist auth session secrets | Platform `Storage` port |
| `BillingSession` | Orchestrate tokens + license + sync + poll | **`2key_core`** |
| `BillingSessionStore` / token store | Persistence ports | Traits in core + platform impls |
| `BillingSdk` (static) | License verify, sync, catalog, payload | **`2key_core`** — instance API preferred |
| `AuthUserProfile` / `BillingAuthTokens` | Shared models | Core models + wrapper types |
| `BillingAccountSession` | Persisted account snapshot | **`2key_core`** |
| Plan catalog / entitlements helpers | Read models | **`2key_core`** |
| Profile merge / JWT enrichment | Sign-in persist helpers | Core or wrapper (must not stay host-only) |

### 6.3 Public Dart package surface (target)

Host apps import:

```dart
import 'package:2key_dart_sdk/2key_dart_sdk.dart';
```

**Must export:** session, auth client facade, license/entitlement APIs, catalog, portal URLs, store interfaces, stable models, `AuthSessionLauncher` (or equivalent callback typedef).

**Must not export:** Better Auth `SessionData`, `AuthClient`, raw plugin types, or Rust/FFI types (unless behind an `advanced/` library and discouraged).

**Internal dependencies (target):**

```yaml
# packages/dart/pubspec.yaml
name: 2key_dart_sdk
dependencies:
  better_auth:          # Phase A auth only — internal
    git:
      url: https://github.com/2keyapp/better-auth.git
      ref: <PINNED_SHA>
      path: packages/clients/dart
# Native logic via flutter_rust_bridge → 2key_core (not a pub dep apps see)
```

### 6.4 Bindings

| Consumer | Binding |
|----------|---------|
| Dart / Flutter | flutter_rust_bridge over a stable Rust facade |
| CLI | Direct Rust (`2key_cli`) |
| Kotlin / Swift | UniFFI from the same facade |
| Browser | TypeScript only — no product FFI/WASM |

See [design.md](proposals/add-rust-core-sdk/design.md) for rationale.

### 6.5 Capabilities checklist (conformance)

Every `2key_*_sdk` (and `2key_core`) MUST support:

1. **Configure** — API base URL + license public key (PEM).
2. **Sign-in** — social (and email if enabled); platform-specific launcher.
3. **Session** — restore, clear, sign-out; detect missing server session vs offline.
4. **API token** — mint/refresh billing JWT (`aud=billing`) from auth session.
5. **Persist account session** — tokens + profile + license JWT + optional ETag.
6. **License init** — verify saved JWT offline (ES256).
7. **License sync** — `GET /api/v1/license` with Bearer; support If-None-Match / 304.
8. **Bootstrap** — `GET /api/v1/subscriptions/me` (or successor).
9. **Catalog** — public plans.
10. **Entitlements read** — from license payload (addons, seats, flags).
11. **Polling / foreground** — optional background sync policy.
12. **Portal handoff** — URL for paying-party portal.
13. **Usage reporting** (when API ships) — `POST /api/v1/usage/events` (or equivalent).
14. **M2M** (when API ships) — mTLS or machine-token flows as documented (Node/Kotlin may lead; Dart if needed).

### 6.6 Platform adapters (per SDK)

| Concern | Dart (FRB wrapper) | Browser TS | CLI | Kotlin / Swift |
|---------|--------------------|------------|-----|----------------|
| OAuth UI | `AuthSessionLauncher` + loopback/deep link | Redirect + cookies | Device/loopback/pasted token | Custom Tabs / ASWebAuthenticationSession |
| Storage | flutter_secure_storage / app-provided | localStorage / cookie jar | OS keyring | Keystore / Keychain |
| Billing logic | **`2key_core`** | Pure TS | **`2key_core`** | **`2key_core`** (UniFFI) |
| mTLS | Optional later | Limited | Strong (lead) | Strong |

---

## 7. Shared protocol (language-agnostic)

### 7.1 Auth (`/api/auth`)

- Hosted Better Auth on billing origin.
- Browser: cookie session + CORS / trusted origins.
- Native: `@2key/auth-native` plugin (deep link / loopback cookie delivery).
- `GET /api/auth/token` (or JWT plugin) → billing API access token.
- Portal session handoff via one-time token (as today).

Document in `docs/auth-protocol.md`. SDKs implement adapters; they do not redefine the protocol.

### 7.2 Billing API (`/api/v1`)

Source of truth: `openapi/2key-billing.yaml`.

Initial groups (extend as features land):

| Group | Examples |
|-------|----------|
| License | `GET /license`, ETag |
| Subscriptions | `GET /subscriptions/me` |
| Plans | `GET /plans` |
| Usage | `POST /usage/events`, `GET /usage/summary` |
| M2M | cert enrollment, identity introspection (mTLS) |

### 7.3 Offline license JWT

- Algorithm: ES256.
- Public key distributed to SDKs (asset/PEM); **private key only on server**.
- Payload fields: subscriptions, addons, expiry, account ids — match **conformance fixtures** (extracted from current Dart decoder).

---

## 8. Product features: placement (critical)

### 8.1 Decision rule

> Would upstream Better Auth ever ship this as core auth?

- **Yes** → fork (prefer upstream PR) or `@2key/auth-native`.
- **No** → **private billing-core / billing-mtls / billing-api**.
- **Client convenience** → `2key_*_sdk`.

### 8.2 Feature placement table

| Feature | Repo / package | Notes |
|---------|----------------|-------|
| Social / email login | better-auth + auth-host | |
| Native redirect/cookie | `@2key/auth-native` | |
| License issue/verify policy | billing-core | |
| Seats / entitlements | billing-core | |
| **Usage-based billing** | billing-core + `/api/v1/usage` | Rapid iteration; not in fork |
| **mTLS M2M** | billing-mtls + API | Machines ≠ Better Auth user sessions |
| Metered entitlements gating | billing-core | |
| Invoicing / credits | billing-core | |
| SDK `reportUsage()` | all `2key_*_sdk` | Thin HTTP |
| SDK mTLS helper | `2key_cli`, `2key_node_sdk`, Kotlin, Swift first | Browser limited; logic in `2key_core` where applicable |

### 8.3 Auth vs machine identity

```
Human user  → Better Auth session → billing API JWT → /api/v1
Machine     → mTLS (billing-mtls) → /api/v1/m2m or same routes with machine principal
```

Do **not** force M2M through Better Auth sessions unless a future generic plugin is upstreamed.

### 8.4 Correct mental model

```
┌─────────────────────────────────────────────────────────────┐
│  2key Billing (PRODUCT) — private server + public SDKs      │
│  mTLS M2M · usage meters · license · plans · entitlements   │
├─────────────────────────────────────────────────────────────┤
│  Auth adapter layer (thin)                                  │
│  “who is this user/session?” via Better Auth host           │
├─────────────────────────────────────────────────────────────┤
│  better-auth FORK — sync from upstream                      │
│  core + native client plugin only                           │
└─────────────────────────────────────────────────────────────┘
```

2key Billing **uses** Better Auth; it is **not** a rebranded Better Auth.

---

## 9. Continuous upstream sync + rapid 2key change

### 9.1 Two velocities

| Velocity | Location | Cadence | Examples |
|----------|----------|---------|---------|
| Slow / sync | `better-auth` fork | Weekly (or on upstream tag) | Core auth fixes, OAuth |
| Fast / product | `2key-billing-server` | Daily | Usage, mTLS, pricing |
| Medium / contract | `2key-billing-sdks` | Per API release | New SDK methods, OpenAPI |

### 9.2 Sync workflow (fork)

1. CI: fetch `upstream/main` (or release tag).
2. Merge into `2keyapp/better-auth`.
3. Run Better Auth + `@2key/auth-native` + Dart client tests.
4. On success: tag / update `release` + `release-native` branches.
5. Notify billing-server to bump pin (manual or bot PR).

### 9.3 Pinning

- **billing-server** pins fork **release branches or SHAs**.
- **`2key_dart_sdk`** pins Dart auth client **SHA** (never floating `main` in production apps).
- Product features ship against current pin; do not wait for upstream to add usage/mTLS.

### 9.4 Patch discipline in the fork

1. Prefer **new packages** (`packages/native`, `packages/clients/*`) over editing upstream files.
2. If core must change: minimal patch + `PATCHES.md` entry + rebase checklist.
3. Never implement usage or mTLS product logic in the fork.

### 9.5 What breaks sync (avoid)

- Implementing usage aggregation inside Better Auth plugins.
- Putting mTLS cert issuance in the Better Auth DB schema.
- Renaming/forking Better Auth tables for “billing accounts” without an adapter.
- Large diffs in `packages/better-auth/**` for 2key product needs.

### 9.6 What preserves sync (do)

- Billing accounts, meters, invoices in **billing DB**.
- Auth host maps `betterAuth.user.id` → `billingAccountId`.
- mTLS identities bound to billing account/API client in **billing-mtls**.
- Optional: Better Auth **hooks** (`onSession`, `onUserCreated`) that call into billing-core — hooks live in **auth-host**, not in the fork.

### 9.7 Coexistence diagram

```
Upstream BA ──weekly merge──► better-auth fork ──pin──► billing-auth-host
                                      │
                                      └──pin──► 2key_dart_sdk auth adapter (internal better_auth)

Daily: billing-core / billing-mtls / billing-api  (no fork required)
Then: OpenAPI bump → update 2key_core + fixtures → wrappers + 2key_ts_sdk
```

---

## 10. How other SDKs are built

### 10.1 Process

1. Change behavior in **`2key_core`** (native) and/or **`2key_ts_sdk`** (browser) + conformance fixtures.
2. Update **OpenAPI** if `/api/v1` changed.
3. Regenerate / update wrappers (Dart FRB, UniFFI, CLI).
4. CI: Rust tests + Dart canary + TS + shared fixture vectors.
5. No SDK may invent divergent license claim names or sync semantics.

During migration, extract fixtures from current Dart tests first, then implement Rust to match.

### 10.2 Priority order

| Priority | Component | Consumer |
|----------|-----------|----------|
| P0 | OpenAPI + conformance fixtures | All |
| P0 | **`two-key` CLI** (Win/macOS/Linux binaries) | Ops, desktop, smoke |
| P0 | **`two-key-core`** in private `2key-core-sdk` | Binary releases |
| P0 | **`2key_dart_sdk`** (`packages/dart`) | Scomm / secMail — **replaces billing_dart_sdk** |
| P0 | **`2key_ts_sdk`** | billing-portal, web |
| P1 | **`2key_react_sdk`** | Portal UI hooks |
| P2 | **`2key_node_sdk`** | Services, mTLS helpers |
| P2 | **`2key_kotlin_sdk`** / **`2key_swift_sdk`** | Native non-Flutter |
| P3 | **`2key_python_sdk`** | Scripts, ops |
| Later | `2key_dotnet_sdk` / `2key_go_sdk` | On demand |

### 10.3 Scomm / secMail integration rules

SComm is a **billing SDK consumer canary only** — not a place for unrelated app/OAuth/security refactors in this workstream.

- Depend only on **`two_key_dart_sdk`** / **`2key_dart_sdk`**.
- Keep in app: OAuth browser/loopback UX, domain entities (`UserEntities`), addon UI.
- Use SDK `BillingMode` + `LicenseBackend.rustCore` (FRB wire → `two-key-core`); do not import Rust crates or `better_auth` in the app.
- DI: single billing wiring module; app_auth and subscriptions both consume SDK types.
- Forbid `package:better_auth` and direct Rust crate imports in the app (CI).

---

## 11. Phased migration

### Phase 0 — Spec lock

- [ ] Adopt this document + [add-rust-core-sdk](proposals/add-rust-core-sdk/proposal.md) (approval gate).
- [ ] Export initial OpenAPI from current `/api/v1`.
- [ ] Write `auth-protocol.md` from current Flutter/native vs browser behavior.
- [ ] Extract Dart public API + JWT/ETag cases into conformance fixtures.

### Phase 1 — Rename & harden Dart (interim reference / canary)

- [ ] Rename `billing_dart_sdk` → **`2key_dart_sdk`** (timing may follow Rust dual-path — see proposal open questions).
- [ ] Pin `better_auth` by SHA; hide Better Auth types from public API.
- [ ] Move host-app profile/session merge logic into Dart SDK.
- [ ] Point Scomm / secMail `pubspec` at `2key_dart_sdk`.
- [ ] Prefer instance license service over static `BillingSdk` (deprecate static).

### Phase 2 — Private server extraction

- [ ] Ensure billing-core / auth-host boundaries in private server repo.
- [ ] Add stubs/modules for **usage** and **mTLS** packages (even if MVP incomplete).

### Phase 3 — Public SDK monorepo + Rust core

- [x] Create `2key-billing-sdks` with `packages/dart`, conformance (core source remains private `2key-core-sdk`).
- [x] Implement `two-key-core` against fixtures + FRB/C ABI offline verify & online sync.
- [x] Dart FRB wire dual-path (`LicenseBackend.rustCore` default when lib present); SComm thin canary.
- [x] Ship `two-key` CLI smoke commands.

### Phase 4 — Browser SDK

- [x] Implement **`2key_ts_sdk`** against OpenAPI + fixtures (parallel to Rust OK).
- [x] Portal-ready SDK surface + [portal-migration.md](portal-migration.md) (SPA cutover when portal repo available).

### Phase 5 — Auth fork hygiene

- [x] Rename `@better-auth/flutter` → `@2key/auth-native` (`packages/native`; shim at `packages/flutter`).
- [x] Relocate Dart client path under `packages/clients/dart`.
- [x] Enable `upstream-sync` workflow + `docs/UPSTREAM_SYNC.md`.
- [x] Publish `release-native` tip and bump `2key-billing` / Dart SDK pins after push.

### Phase 6 — Usage & mTLS product APIs

- [x] Document live `POST /api/v1/usage/report` in OpenAPI; client helpers in core + `@2key/ts-sdk`.
- [ ] Ship mTLS enrollment/verify in billing-mtls (stub: `2key-billing/docs/billing-mtls-stub.md`).
- [ ] Extend wrappers + CLI for mTLS when server ships.

### Phase 7 — Additional languages

- [x] UniFFI scaffold docs (`bindings/uniffi/`, core `docs/UNIFFI.md`).
- [ ] Kotlin / Swift packages against conformance suite.

---

## 12. CI / quality gates

| Repo | Gates |
|------|-------|
| better-auth fork | Upstream merge job; unit tests; no billing-core import |
| 2key-billing-server | API tests; license crypto; usage/mTLS tests; pin SHA check |
| 2key-billing-sdks | `2key_core` tests; Dart FRB canary; TS tests; **shared conformance fixtures must pass** |
| Scomm / secMail | Integration tests against `2key_dart_sdk`; forbid `package:better_auth` / direct Rust imports |

---

## 13. Documentation set

| Doc | Location | Audience |
|-----|----------|----------|
| This architecture | `docs/2key-billing-sdk-architecture.md` (here); later `2key-billing-sdks/docs/architecture.md` | All engineers |
| Rust-core proposal | `docs/proposals/add-rust-core-sdk/` | Approvers / implementers |
| Auth protocol | `docs/auth-protocol.md` | SDK authors |
| OpenAPI | `openapi/2key-billing.yaml` | SDK + server |
| SDK conformance | `docs/sdk-conformance.md` | SDK authors |
| Upstream sync runbook | `better-auth/docs/UPSTREAM_SYNC.md` | Auth maintainers |
| App integration | Scomm / secMail OpenSpec / internal README | App team |

---

## 14. Explicit non-negotiables

1. **`2key_core` + fixtures** are the **native** reference; **`2key_ts_sdk` + fixtures** are the **browser** reference — wrappers must not diverge on claims or sync semantics.
2. **Package names are `2key_<lang>_sdk`** for host-facing SDKs; apps never depend on `2key_core` directly.
3. **Product features (usage, mTLS, metering) live in private billing-server**, not the Better Auth fork.
4. **Host apps never depend on `better_auth` directly**.
5. **Fork stays mergeable** — 2key patches isolated; production pins SHAs.
6. **Public SDKs never contain signing keys or billing-core**.
7. **Browser product API is TypeScript**, not WASM-wrapped `2key_core`.

---

## 15. Open decisions (resolve in Phase 0)

1. Monorepo `2key-billing-sdks` vs standalone repos (monorepo recommended).
2. Keep `Billing*` type names vs rename to `TwoKey*` with aliases.
3. npm scope `@2key/` vs unscoped `2key_ts_sdk` string (recommend `@2key/ts-sdk`).
4. Whether M2M uses only mTLS or also opaque machine tokens for environments without mTLS.
5. Timeline to extract billing-portal onto `2key_ts_sdk`.
6. FRB version / generate-in-CI vs vendored Dart bindings ([design open questions](proposals/add-rust-core-sdk/design.md)).
7. Package rename timing relative to Rust dual-path.
8. Publish `2key_core` on crates.io vs git-only until 1.0.

---

## 16. One-page summary

```
better-auth fork     = syncable auth engine + native plugin + low-level auth clients
2key-billing-server  = private product (license, usage, mTLS, …)
2key-billing-sdks    = 2key_core (NATIVE REF) + 2key_dart_sdk (FRB) + 2key_ts_sdk (BROWSER REF) + …
Apps                 = depend on 2key_<lang>_sdk only
```

Rapid product change happens in the **private server**.  
Continuous upstream sync happens in the **thin fork**.  
Native consistency happens via **`2key_core` + OpenAPI + conformance**.  
Browser consistency happens via **`2key_ts_sdk` + same OpenAPI + conformance**.

**Proposal (awaiting approval):** [docs/proposals/add-rust-core-sdk/](proposals/add-rust-core-sdk/proposal.md)
