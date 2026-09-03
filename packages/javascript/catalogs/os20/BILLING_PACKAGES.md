# OS20 Billing packages (catalog view)

Canonical commercial contract lives with the OS20 Billing deployment seed
(plan codes below). Human seats and machine seats are distinct.

| Package | Plan code | AuthN | AuthZ summary |
|---------|-----------|-------|---------------|
| Team | `os20_team` | Human SSO/session | Shared org namespaces; staging publish; profiles `package_maintainer`, engineers |
| Enterprise | `os20_enterprise` | SSO + optional SCIM; machine certs | Full hierarchy; cross-org partner grants; `organization_owner` / release roles |
| Regulated | `os20_regulated` | Enterprise + HSM / regulated-signer assurance predicates | Same AuthZ catalog; PEP requires stronger assurance for `sign` / `package.publish` |
| Partner seat | `os20_partner_seat` | External IdP or invited user | Profile `supplier_engineer`; visibility `partner` |
| Machine seat | `os20_machine_seat` | CapabilityCredential + client cert | Profiles `release_bot`, `ci_service`, `ai_engineering_agent` |
| Storage (UBB) | `os20_storage_gb` | N/A | Metered artifact storage — entitlement only |

## Paying party

- **Team / Enterprise / Regulated:** organization (Billing entity) pays for human + machine seats.
- **Partner seat:** OEM org typically pays; partner principal is entitled under OEM entity with attenuated grants.
- **Meters:** org pays (`os20.api.calls`, `os20.storage.bytes`, `os20.simulation.seconds`, `os20.registry.egress.bytes`).

## Entitlement composition

At PEPs:

```text
allow iff authorize(CapabilitySet) AND billing entitlement covers mapped action
```

Map JWT / meter gate names → catalog via `ENTITLEMENT_ACTION_MAP` in `src/index.ts`.

## Seed constants

```ts
import { OS20_PLAN_CODES, OS20_METERS } from "@2key/catalog-os20";
```

| Constant | Values |
|----------|--------|
| `OS20_PLAN_CODES` | `team`, `enterprise`, `regulated`, `partnerSeat`, `machineSeat`, `storageGb` |
| `OS20_METERS` | `apiCalls`, `storageBytes`, `simulationSeconds`, `registryEgressBytes` |
