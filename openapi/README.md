# OpenAPI

Canonical HTTP contract for every language SDK in this repo.

| File | Surface |
|------|---------|
| [`2key-billing.yaml`](2key-billing.yaml) | `/api/v1` + machine-authn + agent token |

Language packages generate or hand-write clients against this file. Do not keep a second copy under `packages/dart` or `packages/javascript`.

When the private billing server adds or changes an endpoint, update this spec in the same change that updates conformance fixtures and both language clients.
