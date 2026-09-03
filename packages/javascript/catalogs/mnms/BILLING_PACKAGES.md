# MnMs Billing packages (catalog view)

App-owner organizations pay for human and machine seats. A contractor Admin may
hold seats (or entitlement) under **multiple** app-owner orgs while using one
AuthN identity.

| Package | Plan code | AuthN | AuthZ summary |
|---------|-----------|-------|---------------|
| Starter | `mnms_starter` | Human session | Single app-owner; limited admins; staging-heavy |
| Team | `mnms_team` | SSO optional | Multi-app under one owner; Admin + Ops/Dev profiles |
| Enterprise | `mnms_enterprise` | SSO/SCIM; machine certs | Multi-app, multi-admin hierarchy, audit retention |
| Contractor seat | `mnms_contractor_seat` | Invited external user | Entitled under a specific app-owner; DP grants still attenuated per owner |
| Machine seat | `mnms_machine_seat` | CapabilityCredential + cert | Profile `ci_bot` (and future automation) |

## Paying party

- **Starter / Team / Enterprise:** app-owner organization (Billing entity) pays.
- **Contractor seat:** typically the inviting app-owner pays; one human may have contractor seats under several owners.
- **Meters:** owning org pays (`mnms.api.calls`, `mnms.container.minutes`, `mnms.tablespace.bytes`, `mnms.backup.bytes`).

## Entitlement composition

```text
allow iff authorize(CapabilitySet) AND billing entitlement covers mapped action
```

Map JWT / gate names → catalog via `ENTITLEMENT_ACTION_MAP` in `src/index.ts`.

## Multi-owner billing note

AuthZ union ≠ single billing seat. If Alice administers Acme and Globex:

- She needs entitlement under **each** paying party (or a platform contractor product that lists both), **and**
- Separate DP grants from each app-owner.

Revoking Globex's contractor seat or DP grant must not remove Acme access.

## Seed constants

```ts
import { MNMS_PLAN_CODES, MNMS_METERS } from "@2key/catalog-mnms";
```
