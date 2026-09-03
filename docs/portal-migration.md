# Migrate billing-portal → `@2key/browser-sdk`

**Status:** SDK ready for cutover; **portal SPA repo is not in this workspace**
(`2keyapp/billing-portal` private). This doc is the checklist for when that
repo is available.

## Goal

billing-portal depends only on `@2key/browser-sdk` for:

- AuthN helpers (token mint, portal URLs)
- License sync / verify
- `subscriptions/me` bootstrap
- Public plans catalog
- AuthZ (`authorize` / `enforceLocally`) when the SPA gates privileged actions
- Optional usage report (reporter / M2M — not browser user sessions)

## Cutover steps

1. Add dependency on `@2key/browser-sdk` (npm or git + pinned SHA).
2. Replace hand-rolled `/api/v1/license` fetch with `BillingApiClient.fetchLicense`.
3. Replace bootstrap with `ensureBillingContext`; catalog with `fetchPlans`.
4. Use `acquireApiToken` (or keep a thin Better Auth **client** wrapper that
   only mints tokens, then hand the JWT to the SDK).
5. Use `verifyLicenseJwt` + `parseLicenseClaims` instead of local JWT libs.
6. Use `portalHandoffUrl` / `shopUrl` / `portalPathUrl` for navigation.
7. Remove duplicate claim-name constants; rely on conformance fixtures /
   `LicensePayload` types.
8. CI: forbid imports of private billing-core and native core binaries in the SPA.

## Already on `@2key/browser-sdk` (v0.1+)

| Capability | API |
|------------|-----|
| License GET + ETag | `BillingApiClient.fetchLicense` |
| Bootstrap | `BillingApiClient.ensureBillingContext` |
| Plans | `BillingApiClient.fetchPlans` |
| ES256 verify | `verifyLicenseJwt` |
| Session store helpers | `BrowserSessionManager` |
| Auth token mint | `acquireApiToken` |
| Handoff URL | `portalHandoffUrl` |
| Usage report (reporter) | `reportUsage` |
| AuthZ | `authorize` / `enforceLocally` |

## Still portal-owned (out of SDK MVP)

- Full Stripe checkout / payment-method UI
- Seat admin CRUD screens
- Invoice PDF download UX
- Org picker UI (SDK only signals `orgPickRequired`)

## Verify

```bash
pnpm test && pnpm build
```

Contract: `openapi/2key-billing.yaml` + `docs/sdk-conformance.md`.
