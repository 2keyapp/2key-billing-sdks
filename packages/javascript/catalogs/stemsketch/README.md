# STEMSketch catalog (`@2key/catalog-stemsketch`)

**Product:** STEMSketch  
**serviceId:** `stemsketch`

VS Code extension for authors contributing to an ontology-classified
knowledgebase. Root delegates **ontology trees** (e.g. `physics` vs `biology`)
to admins who may further attenuate. **Submit for review** and **make live
(publish)** are distinct catalog actions.

Requires DP algebra **v2**: `path_prefix` on `ontology`; optional `effect: "deny"`.

## Auth + Billing model

| Layer | Role |
|-------|------|
| **AuthN (humans)** | Better Auth (SSO/org as needed) |
| **AuthN (machines)** | CapabilityCredential + cert for `kb_bot` |
| **AuthZ** | Ontology-scoped CapabilitySets from this catalog |
| **Entitlement** | Author / team seats + machine seats |
| **PEP (authoritative)** | STEMSketch KB / API |
| **PEP (advisory)** | VS Code extension (`@2key/dp-authorize` / `dp-rust`) |

```text
allowed =
  authorize(grants, action, { entity, ontology [, artifact] }, catalog).ok
  AND lifecycle.allows(artifact.state, action)
  AND entitlement.ok
```

**Invariant:** artifact `state` is **not** a grant dimension. User phrase
“delegate `physics.*`” maps to scope `ontology: "physics"` (`path_prefix`),
not action wildcards named after domains.

## Scope dimensions

| Dimension | Algebra | Purpose |
|-----------|---------|---------|
| `entity` | `exact` | Organization / Billing entity |
| `ontology` | `path_prefix` | Domain tree (`physics` ⊇ `physics/mechanics`) |
| `artifact` | `path_prefix` | Optional path to a specific artifact |
| `environment` | `set` | Optional `draft-space` / `staging` / `production` |

## Actions

### Control
`entity.read`, `ontology.read|manage`, `grant.delegate`, `delegation.revoke`,
`admin.invite`, `cert.issue`, `machine.bind`, `seat.bind`

### Knowledge
`kb.discover|read|create|update|delete`  
Review path: `kb.submit_review`, `kb.withdraw_review`, `kb.approve`, `kb.reject`, `kb.request_changes`  
Live path: `kb.publish`, `kb.unpublish`, `kb.deprecate`

`kb.submit_review` does **not** imply `kb.publish`.

## Profiles

| Profile | Use |
|---------|-----|
| `kb_root` | Org kickstart; all ontologies; full delegate |
| `ontology_admin` | Domain admin (issue with `ontology: physics`); can subdelegate |
| `author` | VS Code contribute + submit; deny publish/delegate |
| `reviewer` | Approve/reject; deny publish |
| `publisher` | Make live / unpublish / deprecate |
| `viewer` | Read/discover only |
| `kb_bot` | Import automation; deny approve/publish/delegate |

### Example: root → physics / biology admins

```ts
// Physics admin
{ action: "kb.*", scope: { entity: "org_stem", ontology: "physics" }, delegable: true }
{ action: "grant.delegate", scope: { entity: "org_stem", ontology: "physics" }, delegable: true }

// Biology admin — no physics access
{ action: "kb.*", scope: { entity: "org_stem", ontology: "biology" }, delegable: true }
```

(Expand `kb.*` to concrete catalog actions at issue if preferred; wildcards work via `actionCovers`.)

## Artifact lifecycle (PEP)

See `EXAMPLE_ARTIFACT_LIFECYCLE` / `STEMSKETCH_ARTIFACT_STATES` in `src/index.ts`.

Typical: `draft` → `in_review` → `approved` → `live` → `deprecated`.

## Commercial packages

See [BILLING_PACKAGES.md](./BILLING_PACKAGES.md).

## Remaining (ops)

1. Wire `@2key/catalog-stemsketch` into STEMSketch Billing DP plugin seed.
2. KB API middleware: resolve ontology + state → `authorize` + lifecycle.
3. VS Code capability refresh + command gating (submit vs publish).
4. Seed plan codes / meters.

## Wiring

```ts
import { CATALOG_SEED, SERVICE_ID, PRODUCT_DISPLAY_NAME } from "@2key/catalog-stemsketch";

delegatePermissions({
  serviceId: SERVICE_ID,
  seed: CATALOG_SEED,
  platformCa: { privateJwk, rootPem },
});
```
