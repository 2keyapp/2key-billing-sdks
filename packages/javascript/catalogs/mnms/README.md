# MnMs catalog (`@2key/catalog-mnms`)

Multi-app DevOps control plane. **App-owners** own app trees and delegate
attenuated `CapabilitySet`s to **Admins**, who may further subdelegate to Ops/Dev
specialists. Roles (SysOps, DBAOps, AppDev, …) are **profiles → permission
bundles**, not RBAC primitives.

Requires DP algebra **v2**: `path_prefix` and optional `effect: "deny"`
(see better-auth `docs/adr/0002-dp-algebra-v2.md`).

## Auth + Billing model

| Layer | Role |
|-------|------|
| **AuthN (humans)** | Better Auth sessions (SSO / org as needed); one identity across app-owners |
| **AuthN (machines)** | CapabilityCredential + client cert for CI bots; platform cosign on Entity Root + machine leaf |
| **AuthZ** | Per–app-owner CapabilitySets (prefer store rows keyed by `(userId, appOwnerId)`); PEP **unions** grants |
| **Entitlement** | Human seats per app-owner org; contractor seats; machine seats for CI |
| **PEP (authoritative)** | API Gateway control plane, DB control plane, MnMs console API |
| **PEP (advisory)** | CLI / console UX via `@2key/dp-authorize` / `dp-rust` |

```text
App-Owner (@acme)
  → issue CapabilitySet to Alice { app: "@acme/payments", … }
App-Owner (@globex)
  → issue CapabilitySet to Alice { app: "@globex/crm", … }

Alice (one principal)
  effective grants = Acme ∪ Globex
  authorize() succeeds if any grant covers the request
```

```text
Console / Gateway / DB control API
  → AuthN (session or mTLS)
  → load all grants for principal (multi-owner merge)
  → resolve inventory: app, server, container|tablespace, environment
  → authorize(grants, action, resource, catalog)   [authoritative]
  → audit (include issuing app-owner / grant id)
```

**Invariant:** client allow never overrides server deny. Revoking one owner's
grant must not remove another owner's grants to the same user.

## Resource model

```text
App-Owner  (@acme)
  └── App     (@acme/payments)
        ├── API GW servers → Containers  (@acme/payments/web)
        └── DB servers     → Tablespaces (@acme/payments/ts_main)
```

Canonical paths use `/` segments; PEP/resolvers supply placement (do not trust
client-claimed server/container binding).

## Scope dimensions

| Dimension | Algebra | Purpose |
|-----------|---------|---------|
| `entity` | `exact` | Billing / merchant binding |
| `app` | `path_prefix` | Owner → app → component |
| `server` | `path_prefix` | `gw/…` or `db/…` placement |
| `container` | `path_prefix` | Runtime unit on API GW |
| `tablespace` | `path_prefix` | Data unit on DB server |
| `environment` | `set` | `dev` \| `test` \| `staging` \| `production` |
| `discipline` | `set` | `sysops`, `netops`, `secops`, `dbaops`, `mlops`, `appdev`, `dbdev` |

## Action families

Discipline-prefixed actions so SysOps never implies DBAOps or AppDev:

| Family | Examples |
|--------|----------|
| Control | `app.delegate`, `delegation.grant`, `cert.issue` |
| SysOps | `sysops.container.start`, `sysops.container.exec` |
| NetOps | `netops.lb.modify`, `netops.firewall.modify` |
| SecOps | `secops.secret.rotate` (≠ `secops.secret.read`) |
| DBAOps | `dbaops.tablespace.resize`, `dbaops.backup.restore` |
| MLOps | `mlops.model.deploy`, `mlops.pipeline.run` |
| AppDev | `appdev.deploy.staging` (≠ production) |
| DBDev | `dbdev.migration.apply` (env-scoped; no tablespace resize) |

## Profiles

| Profile | Use |
|---------|-----|
| `app_owner` | Full app tree; delegable |
| `admin` | Broad DevOps under app; can subdelegate |
| `sysops` / `netops` / `secops` / `dbaops` / `mlops` | Leaf Ops specialists |
| `appdev` / `dbdev` | Leaf Dev specialists |
| `auditor` | Read / audit only |
| `ci_bot` | Build + staging deploy; deny prod / exec / delegate |

Issue-time narrowing: replace empty `app: ""` (and container/tablespace) with
concrete `path_prefix` scopes and run `assertSubset` against the issuer.

## Multi-owner Admin (required pattern)

Prefer **Option A** storage:

```text
principal_grant(userId, appOwnerId, permissions, …)
PEP: grants = SELECT … WHERE userId = ?  → flatten CapabilitySet
```

Example:

| Issuer | Subject | Scope |
|--------|---------|-------|
| `@acme` | Alice | `app=@acme/payments`, SysOps+Admin bundle |
| `@globex` | Alice | `app=@globex/crm`, DBAOps bundle |

Alice restarts `@acme/payments/web` (Acme grant) and resizes `@globex/crm/ts_main`
(Globex grant). Cross-app escape fails `NOT_AUTHORIZED`.

## Commercial packages

See [BILLING_PACKAGES.md](./BILLING_PACKAGES.md).

## Remaining (ops)

1. Wire `@2key/catalog-mnms` into the MnMs Billing DP plugin seed.
2. Implement multi-owner principal-grant merge at PEP.
3. Inventory resolver (app ↔ server ↔ container/tablespace).
4. Seed plan codes (`MNMS_PLAN_CODES`) and meters (`MNMS_METERS`).

## Wiring

```ts
import { CATALOG_SEED, SERVICE_ID } from "@2key/catalog-mnms";

delegatePermissions({
  serviceId: SERVICE_ID,
  seed: CATALOG_SEED,
  platformCa: { privateJwk, rootPem },
});
```
