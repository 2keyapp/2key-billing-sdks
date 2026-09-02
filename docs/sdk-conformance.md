# SDK conformance

All `2key_*_sdk` packages and `two-key-core` must pass the shared checklist and fixtures.

## Capability checklist

1. Configure — API base URL + license public key PEM + `storage_prefix` (no brand defaults)
2. Sign-in — platform launcher / redirect (see `auth-protocol.md`)
3. Session — restore, clear, sign-out; missing server session vs offline
4. API token — mint/refresh billing JWT from auth session
5. Persist account session — tokens + profile + license JWT + optional ETag
6. License init — verify saved JWT offline (ES256)
7. License sync — `GET /api/v1/license` with Bearer; If-None-Match / 304
8. Bootstrap — `GET /api/v1/subscriptions/me`
9. Catalog — `GET /api/v1/plans`
10. Entitlements read — from license payload (`subscriptions[]`, `addon_code`, …)
11. Polling / foreground — optional policy (default 6h when entitled)
12. Portal handoff — paying-party URL
13. Usage reporting — when API ships
14. M2M — CLI/node first when API ships

## Fixtures

| Path | Purpose |
|------|---------|
| `conformance/fixtures/license_payload_v1.json` | Canonical claim names + sample subscriptions |
| `conformance/fixtures/license_payload_v3.json` | Offerings license payload |
| `conformance/dp-authz/fixtures.json` | AuthZ authorize / subset / actionCovers vectors |

Rust: `cargo test -p two-key-core` / `dp-rust` in `2key-core-sdk` against the same fixtures.

TypeScript: `@2key/browser-sdk` + `@2key/dp-authorize` tests under `packages/javascript`.
Dart: `cd packages/dart && flutter test`.

## Error codes

See `docs/error-codes.md`. Wrappers must map to the same snake_case strings.

## References

- Native: private `2key-core-sdk` crate `two-key-core` (binaries only in public tree)
- Browser: `@2key/browser-sdk` (`packages/javascript/packages/browser-sdk`)
- Dart: `two_key_dart_sdk` (`packages/dart`)
- OpenAPI: `openapi/2key-billing.yaml`
