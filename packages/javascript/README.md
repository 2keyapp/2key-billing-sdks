# JavaScript / TypeScript workspace

pnpm workspace for `@2key/browser-sdk` and `@2key/dp-*`. Run every command from **this directory**.

```bash
pnpm install
pnpm run ci
```

| Package | Role |
|---------|------|
| `@2key/browser-sdk` | Host entry — AuthN + Billing + AuthZ |
| `@2key/dp-spec` | CapabilityCredential types |
| `@2key/dp-authorize` | Pure AuthZ algebra |
| `@2key/dp-presentation` | PEP ports |
| `@2key/dp-mtls` | Node mTLS materialization |
| `@2key/dp-ts` | DP Admin + Device + Machine AuthN HTTP |
| `@2key/catalog-*` | Tenant catalog seeds |

Hosts depend on **`@2key/browser-sdk` only**.

Conformance fixtures live at the **repo root** (`conformance/`). Tests load them from there. Do not copy fixtures into this workspace.

See the [repo README](../../README.md) and [CONTRIBUTING.md](../../CONTRIBUTING.md).
