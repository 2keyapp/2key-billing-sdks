# Auth protocol — browser vs native

2key Billing hosts Better Auth at `{origin}/api/auth/*`. Billing APIs are at `{origin}/api/v1/*` and expect a **billing API JWT** (`aud=billing`) obtained after a user session exists.

## Shared sequence

```
1. Configure SDK (api origin + license public PEM + storage prefix)
2. Sign-in (platform-specific)
3. Mint / acquire billing API access token from auth session
4. Persist account session (tokens + profile)
5. GET /api/v1/license (Bearer) → ES256 license JWT (+ ETag)
6. Offline verify license; read entitlements
7. Optional: GET /api/v1/subscriptions/me, GET /api/v1/plans
8. Portal handoff (paying-party) via one-time token URL when allowed
```

## Browser (`@2key/ts-sdk`)

| Concern | Behavior |
|---------|----------|
| Session | HTTP-only cookies; `credentials: 'include'` on auth + API same-origin (or CORS + trusted origins) |
| Sign-in | Full-page or popup **redirect** to IdP; return to app origin |
| Token | Session cookie and/or `GET /api/auth/token` style endpoint for API JWT |
| Storage | Cookie jar + `localStorage` / IndexedDB for license JWT + ETag (no Keychain) |
| mTLS | Not supported |

Server must allow the SPA origin in Better Auth trusted origins / CORS.

## Native (`2key_core` wrappers: Dart, CLI, Kotlin, Swift)

| Concern | Behavior |
|---------|----------|
| Session | No browser cookie jar; use `@2key/auth-native` (deep link / loopback `?cookie=` handoff) |
| Sign-in | Host supplies OAuth launcher (Custom Tabs, ASWebAuthenticationSession, desktop loopback) |
| Token | Auth client mints billing API JWT; feed into `2key_core` session |
| Storage | Secure storage port (Keychain / Keystore / DPAPI / Flutter secure storage) namespaced by `storage_prefix` |
| CLI | Device code / loopback / pasted token; OS keyring |
| License | Offline: ES256 verify via `two-key-core` (FRB). Online: ensure device key → `POST /api/v1/license/devices` → `ensure_billing_context` + `sync_license` (ETag). Canonical bind UI: SPA `{portal}/settings/devices`. No-JS fallback: billing `GET /portal/devices`. |
| Device bind | Per-seat `maxDevices` from plan `features_json`; SComm Connect = 5. At limit require `replaceSki`. License JWT includes `devices[].ski` + `max_devices` |
| BillingMode | Dart `BillingSession.mode`: `offline` blocks license HTTP; `online` allows sync/poll |

OAuth / PKCE / loopback stay in the host + auth adapter — **not** in `two-key-core`.

## Machine identity (not Better Auth)

```
Machine → mTLS or machine token → /api/v1
```

Implemented later in CLI / Node helpers — not in the browser SDK.

## Non-goals

- Redefining Better Auth wire formats inside SDKs
- Shipping auth private keys in clients
- Using WASM `2key_core` as the browser product API
