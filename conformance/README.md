# Conformance fixtures

Shared test vectors. Dart (`packages/dart/test`) and JavaScript (`packages/javascript/packages/*/src/**/*.test.ts`) must both pass these.

| Path | Purpose |
|------|---------|
| `fixtures/license_payload_v1.json` | License JWT claim names (legacy payload) |
| `fixtures/license_payload_v3.json` | Offerings license payload |
| `fixtures/machine_authn_*.json` | Machine enroll HTTP |
| `fixtures/agent_token_*.json` | Agent token mint HTTP |
| `dp-authz/fixtures.json` | AuthZ authorize / subset / actionCovers |

Dart and JavaScript tests load this directory from the repo root. Native core (`2key-core-sdk`) should keep the same vectors.

A renamed claim that only updates one language is a failed PR.
