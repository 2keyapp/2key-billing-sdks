# STEMSketch Billing packages (catalog view)

| Package | Plan code | AuthN | AuthZ summary |
|---------|-----------|-------|---------------|
| Starter | `stemsketch_starter` | Human session | Limited ontologies; author/viewer |
| Team | `stemsketch_team` | SSO optional | Multi-ontology; ontology_admin + authors/reviewers |
| Enterprise | `stemsketch_enterprise` | SSO/SCIM; machine certs | Full hierarchy; publishers; audit |
| Author seat | `stemsketch_author_seat` | Human | Profile `author` under invited ontology scopes |
| Machine seat | `stemsketch_machine_seat` | CapabilityCredential + cert | Profile `kb_bot` |

## Paying party

Organization (Billing entity) pays for human and machine seats.

## Entitlement composition

```text
allow iff authorize(CapabilitySet) AND billing entitlement covers mapped action
```

Map via `ENTITLEMENT_ACTION_MAP` in `src/index.ts`.

## Meters

| Meter | Code |
|-------|------|
| API calls | `stemsketch.api.calls` |
| Active artifacts | `stemsketch.artifacts.active` |
| Storage | `stemsketch.storage.bytes` |
| Publish events | `stemsketch.publish.events` |

## Seed constants

```ts
import { STEMSKETCH_PLAN_CODES, STEMSKETCH_METERS } from "@2key/catalog-stemsketch";
```
