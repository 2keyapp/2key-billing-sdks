# Scomm Workflows Billing packages (catalog view)

| Package | Plan code | AuthN | AuthZ summary |
|---------|-----------|-------|---------------|
| Starter | `scomm_workflows_starter` | Human session | Limited channels; author/reviewer profiles |
| Team | `scomm_workflows_team` | SSO optional | Multi-channel; channel_admin + specialist profiles |
| Enterprise | `scomm_workflows_enterprise` | SSO/SCIM; machine certs | Hierarchical channels; audit; automation bots |
| Machine seat | `scomm_workflows_machine_seat` | CapabilityCredential + cert | Profile `workflow_bot` |

## Paying party

Organization (Billing entity) pays for human and machine seats.

## Entitlement composition

```text
allow iff authorize(CapabilitySet) AND billing entitlement covers mapped action
```

Map JWT / gate names via `ENTITLEMENT_ACTION_MAP` in `src/index.ts`.

## Meters

| Meter | Code |
|-------|------|
| API calls | `scomm.workflows.api.calls` |
| Active documents | `scomm.workflows.documents.active` |
| Storage | `scomm.workflows.storage.bytes` |
| FSM transitions | `scomm.workflows.transitions` |

## Seed constants

```ts
import { SCOMM_PLAN_CODES, SCOMM_METERS } from "@2key/catalog-scomm";
```
