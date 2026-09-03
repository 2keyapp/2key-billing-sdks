# Platform tenants

Hosted multi-tenant Auth + Billing products. Each tenant is typically **one app deployment / one Postgres DB** (merchant isolation), with its own DP catalog seed in [`catalogs/`](catalogs/).

AuthN = Better Auth · AuthZ = `delegate-permissions` CapabilitySets · Entitlement = Billing seats (human + machine).

| Slug | Display | Catalog package | Auth + Billing model |
|------|---------|-----------------|----------------------|
| `demo` | Demo | `@2key/catalog-demo` | Example only — hierarchical host / machine seats |
| `scomm` | Scomm Workflows | `@2key/catalog-scomm` | **Populated** — Channels + FSM documents; see `catalogs/scomm/README.md` |
| `idr` | IDR | `@2key/catalog-idr` | **Populated** — Personal/Enterprise/SP + Data Transfer UBB; see `catalogs/idr/BILLING_PACKAGES.md` |
| `os20` | OS20 | `@2key/catalog-os20` | **Populated** — Team/Enterprise/Regulated + machine/partner seats; see `catalogs/os20/README.md` |
| `stemsketch` | STEMSketch | `@2key/catalog-stemsketch` | **Populated** — Ontology KB + VS Code; see `catalogs/stemsketch/README.md` |
| `mnms` | MnMs | `@2key/catalog-mnms` | **Populated** — App-owner → Admin DevOps delegation; multi-owner grants; see `catalogs/mnms/README.md` |

## IDR (detailed)

Canonical notes: [`catalogs/idr/README.md`](catalogs/idr/README.md).

1. **AuthN** — Humans: Better Auth. Machines (Target/Source): CapabilityCredential + client cert; platform cosign on Entity Root + Machine leaf.
2. **AuthZ** — `@2key/catalog-idr` (FQHN `dns_prefix` hierarchy; Presence/session/TURN/ACL actions).
3. **Billing** — Human seats + permanent machine seats; Target Agents mint Presence entitlement JWT at `POST /api/auth/agent/token` (`using_party` / `paying_party` in claims). No Presence mux.
4. **PEP** — Presence (QUIC primary / WSS fallback); JWKS-verify JWT and authorize in-process.
5. **Transports** — Target→Presence: QUIC/WSS + cert (SDK mTLS helpers). WebRTC Source path: app `PepConnector` + in-band credential presenter.

**Remaining:** wire `@2key/catalog-idr` into the Billing DP plugin (still demo seed); production DNS for `auth.idr.to`.

## OS20 (detailed)

Canonical notes: [`catalogs/os20/README.md`](catalogs/os20/README.md).

1. **AuthN** — Humans: Better Auth (SSO/org). Machines: CapabilityCredential + client cert for CI, release bots, AI agents; platform cosign on Entity Root + machine leaf.
2. **AuthZ** — `@2key/catalog-os20` (`path_prefix` org/resource, `semver` version, set semantic/lifecycle/visibility/environment; optional explicit deny). Requires DP algebra v2.
3. **Billing** — Human seats + machine seats + partner seats; Team / Enterprise / Regulated plans; storage and usage meters (`OS20_PLAN_CODES`, `OS20_METERS`).
4. **PEP** — **OS20 API** and **package registry** are authoritative (`authorize` + entitlement). Engineering Workbench / CLI use advisory `enforceLocally` / `dp-rust`.
5. **Graph** — Resolver supplies resource ancestry and lifecycle; node vs edge visibility (`read` vs `relation.read`).

**Remaining:** wire `@2key/catalog-os20` into the OS20 Billing DP plugin seed; API middleware + Workbench capability refresh; ontology URN expansion at PEP.

## MnMs (detailed)

Canonical notes: [`catalogs/mnms/README.md`](catalogs/mnms/README.md).

1. **AuthN** — Humans: Better Auth (one identity across app-owners). Machines: CapabilityCredential + cert for CI bots.
2. **AuthZ** — `@2key/catalog-mnms` (`path_prefix` app/server/container/tablespace; discipline-prefixed SysOps/NetOps/SecOps/DBAOps/MLOps/AppDev/DBDev actions). App-owners delegate to Admins who may subdelegate. Same Admin unions grants from multiple owners.
3. **Billing** — Starter/Team/Enterprise + contractor/machine seats (`MNMS_PLAN_CODES`, `MNMS_METERS`).
4. **PEP** — API Gateway and DB control planes + MnMs console API (authoritative). Prefer principal-grant rows keyed by `(userId, appOwnerId)`.
5. **Inventory** — Resolver binds containers (API GW) and tablespaces (DB servers) to apps before AuthZ.

**Remaining:** wire `@2key/catalog-mnms` into MnMs Billing DP plugin seed; multi-owner grant merge middleware; inventory resolver.

## Scomm Workflows (detailed)

Canonical notes: [`catalogs/scomm/README.md`](catalogs/scomm/README.md).

1. **AuthN** — Humans: Better Auth. Machines: CapabilityCredential + cert for workflow bots.
2. **AuthZ** — `@2key/catalog-scomm` (`path_prefix` channel, optional `doc_kind` set). Profiles: channel_admin, author, reviewer, publisher, viewer, workflow_bot. FSM transition names = catalog actions; state enforced at PEP (not in grants).
3. **Billing** — Starter/Team/Enterprise + machine seats (`SCOMM_PLAN_CODES`, `SCOMM_METERS`).
4. **PEP** — Workflows API: `authorize()` then channel FSM `allowedActions[state]`. Inbox = grants × FSM intersection.
5. **Display** — Product name **Scomm Workflows**; serviceId slug remains `scomm`.

**Remaining:** wire catalog into Scomm Billing DP plugin seed; FSM-aware API middleware; inbox query.

## STEMSketch (detailed)

Canonical notes: [`catalogs/stemsketch/README.md`](catalogs/stemsketch/README.md).

1. **AuthN** — Humans: Better Auth. Machines: CapabilityCredential + cert for KB import bots.
2. **AuthZ** — `@2key/catalog-stemsketch` (`path_prefix` ontology; optional artifact/environment). Root delegates ontology trees (e.g. `physics` vs `biology`) to admins who subdelegate. `kb.submit_review` ≠ `kb.publish`.
3. **Billing** — Starter/Team/Enterprise + author/machine seats (`STEMSKETCH_PLAN_CODES`, `STEMSKETCH_METERS`).
4. **PEP** — KB/API authoritative (`authorize` + artifact lifecycle). VS Code extension advisory.
5. **Display** — Product name **STEMSketch**; serviceId `stemsketch`.

**Remaining:** wire catalog into STEMSketch Billing DP plugin seed; VS Code capability refresh; lifecycle-aware API middleware.

## Related servers

- Better Auth fork — generic `delegate-permissions` (no product seeds in core)
- Billing — one merchant DB per deployment; machine seats + agent token mint; wire `seatBinder` / catalog when machine seats apply
- Product / agent / web SDKs — tenant-owned; depend on `@2key/catalog-<slug>` + **`@2key/browser-sdk`** / `@2key/dp-*` from **`packages/javascript/`** in this repo
- Native Rust DP — `2key-core-sdk` (`dp-rust*`, `dp-cli`)
