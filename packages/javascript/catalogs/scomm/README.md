# Scomm Workflows catalog (`@2key/catalog-scomm`)

**Product:** Scomm Workflows  
**serviceId:** `scomm`

Channel-scoped document workflows. Users hold **actions** on **channels**;
**documents** are instances on a channel whose lifecycle is a **per-channel FSM**.
Roles are **profiles → CapabilitySets**, not RBAC primitives.

Requires DP algebra **v2**: `path_prefix` (channels) and optional `effect: "deny"`.

> Formerly sketched under the working name “xdoc”. The stable slug remains `scomm`.

## Auth + Billing model

| Layer | Role |
|-------|------|
| **AuthN (humans)** | Better Auth sessions (SSO / org as needed) |
| **AuthN (machines)** | CapabilityCredential + cert for `workflow_bot` / automation |
| **AuthZ** | Channel-scoped CapabilitySets from this catalog |
| **Entitlement** | Human seats + machine seats; org pays |
| **PEP (authoritative)** | Scomm Workflows API — `authorize()` **then** FSM check |
| **PEP (advisory)** | Web/CLI UI via `@2key/dp-authorize` / `dp-rust` |

```text
allowed =
  authorize(grants, action, { entity, channel [, doc_kind] }, catalog).ok
  AND fsm.allows(channelId, doc.state, action)
  AND entitlement.ok
```

**Invariant:** document `state` is **not** a grant dimension. The algebra does
not encode FSM state; the channel FSM config + document row do.

## Scope dimensions

| Dimension | Algebra | Purpose |
|-----------|---------|---------|
| `entity` | `exact` | Organization / Billing entity |
| `channel` | `path_prefix` | Channel tree (`legal` ⊇ `legal/contracts`) |
| `doc_kind` | `set` | Optional template filter (`invoice`, `contract`, …) |

Omitted `channel` on a grant = all channels under the entity (parent ALL).

## Actions

### Control plane
`entity.read`, `channel.create|read|configure|delete`, `grant.delegate`,
`delegation.revoke`, `admin.invite`, `cert.issue`, `machine.bind`, `seat.bind`

### Document plane
CRUD: `doc.create|read|list|update|delete|comment`  
FSM transitions: `doc.submit|approve|reject|request_changes|publish|archive|restore`

Every string in a channel FSM’s `allowedActions` / `transitions` **must** be a
catalog action (see `EXAMPLE_INVOICE_FSM` in `src/index.ts`).

## Profiles

| Profile | Use |
|---------|-----|
| `channel_admin` | Configure FSM, delegate, full doc ops |
| `author` | Create/edit/submit; deny approve/publish |
| `reviewer` | Read + approve/reject/request_changes |
| `publisher` | Publish/archive/restore |
| `viewer` | Read/list/comment only |
| `workflow_bot` | Automation create/submit; deny approve/configure/delegate |

Issue-time narrowing: set `entity` and concrete `channel` (e.g. `finance/invoices`)
and run `assertSubset` against the issuer.

## Visibility / inbox

Not a single `authorize()` call:

```text
for each channel C the user can access:
  for each document D on C:
    visible if intersection(fsm.allowedActions[D.state], userActionsOn(C)) ≠ ∅
```

A reviewer sees docs in `pending_review` because they hold `doc.approve` and
that action is allowed in that state.

## Delegation

Uses existing `assertSubset()`:

```text
channel_admin { doc.*, channel: "" }
  → lead { doc.*, channel: "legal" }
    → member { doc.approve, channel: "legal/contracts", delegable: false }
```

## Commercial packages

See [BILLING_PACKAGES.md](./BILLING_PACKAGES.md).

## Remaining (ops)

1. Wire `@2key/catalog-scomm` into the Scomm Workflows Billing DP plugin seed.
2. Implement API PEP: AuthN → grants → `authorize` → load channel FSM → transition.
3. Inbox query implementing grants × FSM intersection.
4. Seed plan codes (`SCOMM_PLAN_CODES`) and meters (`SCOMM_METERS`).

## Wiring

```ts
import {
  CATALOG_SEED,
  SERVICE_ID,
  PRODUCT_DISPLAY_NAME,
} from "@2key/catalog-scomm";

delegatePermissions({
  serviceId: SERVICE_ID,
  seed: CATALOG_SEED,
  platformCa: { privateJwk, rootPem },
});
```
