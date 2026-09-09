# Auth protocol — browser vs native

2key Billing hosts Better Auth at `{origin}/api/auth/*`. Billing APIs are at `{origin}/api/v1/*` and expect a **billing API JWT** (`aud=billing`) obtained after a user session exists.

## Shared sequence

```
1. Configure SDK (api origin + license public PEM + storage prefix)
2. Using-party: generate DeviceID, copy public JSON, bind+issue in the portal, paste snapshot
3. Paying-party: sign-in (platform-specific), mint billing API JWT for portal/shop
4. Persist account session (tokens + profile) where needed for portal
5. Do not GET /api/v1/license from using-party clients (410 by default)
6. Offline verify signed snapshot; read entitlements (no JWT exp; any past valid_until rejects)
7. Optional: GET /api/v1/plans for shop CTAs
8. Portal handoff (paying-party) via one-time token URL when allowed
```

## Browser (`@2key/browser-sdk`)

| Concern | Behavior |
|---------|----------|
| Session | HTTP-only cookies; `credentials: 'include'` on auth + API same-origin (or CORS + trusted origins) |
| Sign-in | Email/password (`signInWithEmail`) or full-page/popup **redirect** to IdP; return to app origin |
| Token | Session cookie and/or `GET /api/auth/token`. Using-party: `acquireUsingPartyApiToken` / Dart `acquireApiToken` auto-binds `me`. Paying-party portal binds a slug first. |
| Device | `createBillingClient().ensureDeviceId()` then `exportDevicePaste()` for portal bind |
| Storage | Cookie jar (portal) + `localStorage` / IndexedDB for license snapshot + device key (no Keychain) |
| License | Offline: ES256 verify of signed JSON snapshot. No in-app GET `/api/v1/license`. |
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
| License | Offline: ES256 verify of a portal-issued signed snapshot (no JWT `exp`). Online GET sync is disabled. Canonical bind UI: SPA `{portal}/settings/devices`. |
| Device bind | Per-seat `maxDevices` from plan `features_json`; SComm Connect = 5. At limit require `replaceSki`. Snapshot includes `devices[].ski` + `max_devices` |
| BillingMode | Dart `BillingSession.mode` defaults to `offline` (blocks license HTTP). `online` stays compiled. |

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
