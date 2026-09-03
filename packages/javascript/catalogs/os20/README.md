# OS20 catalog (`@2key/catalog-os20`)

Engineering package manager and VS Code Engineering Workbench tenant.
AuthZ is **delegated permissions** (`CapabilitySet` attenuation) over semantic
engineering graphs — not RBAC. Roles/profiles are convenience bundles only.

Requires DP algebra **v2**: `path_prefix`, `semver`, and optional `effect: "deny"`
(see better-auth `docs/adr/0002-dp-algebra-v2.md`).

## Auth + Billing model

| Layer | Role |
|-------|------|
| **AuthN (humans)** | Better Auth sessions (SSO / org membership as needed) |
| **AuthN (machines)** | CapabilityCredential + client cert (CI, release bots, AI agents); platform cosign on Entity Root + machine leaf |
| **AuthZ** | `delegate-permissions` CapabilitySets from this catalog (`path_prefix` org/resource, `semver` version, set semantic/lifecycle/…) |
| **Entitlement** | Billing **human seats** + permanent **machine seats**; short-lived Workbench capability / API entitlement JWT |
| **PEP (authoritative)** | **OS20 API** + **package registry** — always re-`authorize()` server-side |
| **PEP (advisory)** | **Engineering Workbench** / CLI (`@2key/dp-authorize` / `dp-rust`) — UX only |

```text
Human / Workbench
  → Better Auth session (or mTLS machine)
  → fetch catalogGeneration + principal/session CapabilitySet
       (or signed EffectiveCapability)
  → local enforceLocally()  [advisory]
  → OS20 API mutation
       ├─ AuthN (session / cert / PoP)
       ├─ load grants + org policy denies
       ├─ resolve lifecycle / visibility / graph ancestry (server truth)
       ├─ authorize(grants, action, resource, catalog)  [authoritative]
       ├─ assurance + approval quorum (PEP extensions)
       └─ audit decision

Release bot / CI
  → CapabilityCredential + HSM-backed key (where required)
  → POST registry publish
       └─ same server PEP + entitlement JWT actions (ENTITLEMENT_ACTION_MAP)
```

**Invariant:** client allow never overrides server deny. Revocation and catalog
generation mismatch fail closed.

## Scope dimensions

| Dimension | Algebra | Purpose |
|-----------|---------|---------|
| `entity` | `exact` | Billing / merchant entity binding |
| `org` | `path_prefix` | `@acme`, `@acme/engineering`, … |
| `resource` | `path_prefix` | Package / element / property paths |
| `semantic` | `set` | Ontology URNs (`urn:os20:semantic:geometry`, …) |
| `relation` | `set` | Edge types (`kerml:specializes`, `os20:validates`, …) |
| `lifecycle` | `set` | `draft` … `archived` |
| `visibility` | `set` | `private` … `public` |
| `version` | `semver` | Exact version vs range grants |
| `environment` | `set` | `local` … `public-registry` |

**Not a scope dimension:** assurance (SSO / X.509 / HSM / regulated-signer) —
verified by AuthN and checked as a PEP predicate.

Canonical IDs and constants: `OS20_SEMANTIC_DOMAINS`, `OS20_RELATION_TYPES`,
`OS20_LIFECYCLE_STATES`, `OS20_VISIBILITY_LEVELS`, `OS20_ENVIRONMENTS` in
`src/index.ts`.

## Profiles

| Profile | Use |
|---------|-----|
| `organization_owner` | Org bootstrap; full delegable authority |
| `package_maintainer` | Draft/working mutate + release prep |
| `geometry_engineer` | Geometry modify/review in draft\|working |
| `simulation_engineer` | Simulation modify/execute/approve (limited delegate) |
| `validation_engineer` | Validation review/approve/attest |
| `release_manager` | Lifecycle release/publish + disclosure promote |
| `release_bot` | Non-delegable production/public-registry publish+sign |
| `ci_service` | Read/execute; staging publish; deny sign/delegate |
| `ai_engineering_agent` | Read/propose/execute; deny approve/sign/publish/delegate |
| `supplier_engineer` | Partner visibility; requirements/compliance limited write |
| `auditor` | Read/discover only; deny mutate/approve/publish |

Issue-time narrowing: replace empty `org: ""` / `resource: ""` with concrete
path_prefix scopes (e.g. `@acme/turbofan`) via `assertSubset` against the issuer.

## PEP surfaces

| Surface | Enforcement |
|---------|-------------|
| OS20 HTTP API | Middleware: AuthN → grants → resolve context → `authorize` → optional approval engine → audit |
| Public / enterprise registry | Same; require `package.publish` + environment scope + signed release manifest |
| Graph / resolver queries | Pre-filter nodes/edges (`read` vs `relation.read`); no post-only filtering at trust boundary |
| VS Code Workbench | `enforceLocally` for menus/commands; never sole gate for mutations |
| CI / Git checks | Emit semantic AuthZ checks; Git permissions ≠ OS20 authority |

## Org policy composition (PEP)

Effective decision:

```text
mandatory org denies
  → authorize(CapabilitySet)
  → assurance predicates
  → approval / quorum (if policy requires)
```

Example mandatory deny (not on the owner profile — composed from org policy store):

```ts
{
  action: "disclosure.promote",
  scope: { org: "@acme", visibility: ["public"] },
  delegable: true,
  effect: "deny",
}
```

Open-source namespaces receive an explicit governed exception grant.

## Commercial packages

See [BILLING_PACKAGES.md](./BILLING_PACKAGES.md).

| Package | Notes |
|---------|-------|
| Team | Human seats; shared namespaces; staging registry |
| Enterprise | Hierarchy, SCIM/SSO, machine seats, partner grants |
| Regulated | HSM/regulated-signer gates; stronger audit retention |
| Partner seat | External supplier visibility (partner) |
| Machine seat | CI / release bot / AI agent permanent seat |
| Storage | Metered package artifact storage |

## Remaining (ops)

1. Wire `@2key/catalog-os20` into the Billing DP plugin seed for the OS20 deployment DB.
2. Implement OS20 API AuthZ middleware + Workbench capability refresh.
3. Seed Billing plan codes (`OS20_PLAN_CODES`) + meters (`OS20_METERS`).
4. Ontology service binding for semantic URN expansion at PEP.

## Wiring

```ts
import { CATALOG_SEED, SERVICE_ID } from "@2key/catalog-os20";

delegatePermissions({
  serviceId: SERVICE_ID,
  seed: CATALOG_SEED,
  platformCa: { privateJwk, rootPem },
});
```

See `ENTITLEMENT_ACTION_MAP` in `src/index.ts` for registry/API JWT action names.
