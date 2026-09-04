# Embed `@2key/browser-sdk` in SComm Outlook add-in

**Status:** JS SDK parity for DeviceID / license session / catalog gates is in `@2key/browser-sdk`. Office hard cut is still open.  
**Constraint:** Greenfield. No shims, aliases, or license v1 dual-path.  
**Production add-in origin:** `https://office.scomm.ai`  
**Hosts:** `scomm-ai/office` (`apps/outlook-addin`); secMail stays on Dart.

## 1. North star — the two SDKs match

`2key_dart_sdk` and `@2key/browser-sdk` are the **same using-party product** on two runtimes. The JS SDK exists so browser hosts (Outlook, portal) cannot drift from Flutter. They must stay identical in functionality.

| Capability | What the host calls the SDK to do | Dart today | JS today |
|------------|-----------------------------------|------------|----------|
| **Generate DeviceID** | Create and persist a local license-device identity (Ed25519, SKI) | `LicenseDeviceKeystore.ensureForAccount` | `createBillingClient().ensureDeviceId()` / `LicenseDeviceKeystore` |
| **Populate signed license key** | Restore / sync / verify the ES256 license JWT and cache it | `BillingSession` + `GET /api/v1/license` (ETag) + bind device | `restore()` / `syncLicense()` / `pasteLicense()` |
| **Answer product gates** | `hasProduct` / `hasOffering` / `hasAddon` / resource quotas | `LicenseEntitlements` (+ optional `OfferingCatalog`) | `licenseEntitlements(..., catalog)` / `billing.entitlements()` |

Outlook (and every other JS app) must go through `@2key/browser-sdk` for those three. The add-in must not parse JWTs or invent entitlement math.

**AuthZ / Rust:** Delegate Permissions, capability algebra, and embedding `two-key-core` (WASM or otherwise) are **not an SComm Outlook use-case for now**. Do not block the add-in on that. Keep AuthZ in the JS SDK for other tenants; Outlook only needs the billing/license/device surface above.

## 2. Runtime split (packaging, not product)

Same OpenAPI, same conformance fixtures, same gate names. Different language wrappers.

| Runtime | Package | Path in this repo |
|---------|---------|-------------------|
| Flutter / native | `2key_dart_sdk` | `packages/dart` (FFI → `two-key-core` binaries) |
| Browser / Office.js | `@2key/browser-sdk` | `packages/javascript/packages/browser-sdk` (TypeScript; Web Crypto) |

`scomm-ai/office` is a **host**, not an SDK. It must not contain license parsers, `better-auth`, or offering math.

## 3. Commercial catalog (static offerings)

At **configure**, the host passes the products and offerings **this binary knows how to gate**. At **runtime**, the signed license says which of those the user has.

```
static catalog (build)  ∩  verified license JWT (runtime)  →  gates + quotas
```

`GET /api/v1/plans` is shop/CTA only — never the source of what the app enforces.

Do **not** use `@2key/catalog-scomm` for Outlook. That seed is Scomm Workflows (channels / FSM). Outlook/secMail codes are the SecMail product (`ai_assistant`, `scomm_connector`, `pgp`, `linux`, …) plus IDR if Local AI is billed.

### Target host API (after parity)

```ts
const billing = createBillingClient({
  apiBaseUrl,
  publicKeyPem,
  storagePrefix: "scomm-office",
  catalog: SCOMM_OFFICE_CATALOG,
});

const device = await billing.ensureDeviceId(); // persist SKI / JWK
await billing.restore();                       // verify cached signed license
await billing.syncLicense();                   // GET /license, bind device if needed
const e = billing.entitlements();

if (!e.hasProduct("secmail")) { /* locked */ }
if (e.hasOffering("ai_assistant") || e.hasAddon("ai_assistant")) { /* BYOAI */ }
```

Unknown JWT offerings are ignored. Catalog offerings missing from the JWT fail closed. License JWT never contains prices.

## 4. SDK work before Office (`packages/javascript/packages/browser-sdk`)

Match Dart. Do not invent a Dart-shaped facade (`BillingSdk` statics); use the same **behaviors and claim names**.

1. **DeviceID** — `ensureDeviceId` / keystore (IndexedDB or host store) + `POST /api/v1/license/devices` (bind, `issueLicense`, `replaceSki`, device limit). Parity with `LicenseDeviceKeystore` + `bindLicenseDevice`. Reuse Ed25519 helpers already in `@2key/dp-ts`.
2. **Signed license** — session orchestrator: restore, ES256 verify, ETag sync, paste-token, optional poll. Lift Office’s local `BillingSession` behaviors under SDK names.
3. **Gates** — `configure({ catalog })` so `hasProduct` / `hasOffering` / `hasAddon` / `resourceForProduct` are fail-closed against the static list. Conformance: `license_payload_v3.json`.
4. **AuthN** — email/password, provider discovery, `acquireUsingPartyApiToken` (auto-bind `me`). No Better Auth types exported. Outlook WebViews cannot rely on third-party cookies.

Defer: DP `authorize()`, machine mTLS, embedding Rust AuthZ.

## 5. Office hard cut (`scomm-ai/office`)

One change, no shim:

1. Pin `@2key/browser-sdk`.
2. Rewrite `AccountBillingPanel` onto DeviceID + license sync + gates.
3. Point `@scomm-office/byoai` at SDK `hasAddon("ai_assistant")` / `hasOffering`.
4. **Delete** `packages/billing`.
5. CI-forbid `better-auth` and local JWT parsers.
6. Rewrite OpenSpec `006-billing-auth-js`: host consumes the JS SDK; do not port Dart.

Keep in Office:

- Dual identity: mailbox (Office.js / MSAL) ≠ billing SSO.
- `displayDialogAsync` for social OAuth / portal (SDK builds URLs).
- CSP + trusted origins for **`https://office.scomm.ai`** (prod) and `https://localhost:5173` (dev).
- Trust boundary: never send mail bodies or Graph tokens to billing.

IDR stays `@idrto/idr_browser_sdk`. Billing only gates it.

## 6. Sequence

```
1. configure (origin, PEM, storagePrefix, static catalog)
2. ensureDeviceId
3. restore cached signed license → paint gates immediately
4. sign-in if needed (email or Office dialog)
5. acquireUsingPartyApiToken → bind device if unbound → GET /api/v1/license
6. verifyLicenseJwt → entitlements vs catalog
7. locked features → Settings billing portal URL (prices stay on the portal)
```

## 7. Work order

### A — `@2key/browser-sdk` (parity with Dart)

- [x] License DeviceID generate/persist + `POST /api/v1/license/devices`
- [x] Session: restore, sync, paste, poll; populate signed license key
- [x] `configure({ catalog })` + fail-closed `hasProduct` / `hasOffering` / `hasAddon`
- [x] Email/password + provider discovery AuthN
- [x] Shared fixtures vs Dart (`license_payload_v3.json`)

### B — `scomm-ai/office`

- [ ] Pin `@2key/browser-sdk`
- [ ] Rewrite Account/Billing + byoai gates
- [ ] Delete `@scomm-office/billing`
- [ ] CSP `connect-src` for billing host; AppDomains / trustedOrigins include `https://office.scomm.ai`
- [ ] Update OpenSpec 006

### C — Billing host

- [x] CORS / Better Auth trusted origins: `https://office.scomm.ai`, `https://localhost:5173`
- [x] Same-origin Office OAuth start (`/oauth/office-start.html`) + OTT complete (`/oauth/office-complete`) — Outlook cannot use cross-origin `SameSite=Lax` state cookies

## 8. Out of scope (confirmed)

- JS S/MIME
- Office product backend (`005-no-office-server` still holds)
- Checkout / invoices / seat admin (portal)
- Replacing IDR transport with billing
- Embedding Rust AuthZ / DP into the Outlook add-in (not an SComm use-case for now)
- Changing secMail’s Dart integration (it already consumes `2key_dart_sdk`; JS must match it)

## 9. Product questions (not SDK mechanics)

These do not change DeviceID / license / gates. They only decide **URLs** and **which offering codes** Outlook checks.

### Where does the add-in call billing?

`https://office.scomm.ai` is the **add-in** (task-pane HTML/JS). The **billing API** is `/api/auth` + `/api/v1/license` on some host.

- Same host: add-in pages and billing APIs both under `office.scomm.ai` (simplest cookies/CSP).
- Different host: e.g. add-in at `office.scomm.ai`, API at `billing.scomm.ai`. Then CSP `connect-src` and CORS/trusted origins must list that API origin.

Until this is named, `VITE_BILLING_ORIGIN` stays an env var.

### Same shop SKUs as secMail, or a new Outlook product?

secMail already bills add-ons like `ai_assistant`, `pgp`, `scomm_connector`. Outlook needs to gate similar features.

- **Same offerings:** one subscription unlocks secMail *and* Outlook. Gate codes match Flutter. Prefer this if Outlook is “secMail in Office.”
- **Dedicated Office product:** Outlook is sold separately, new offering codes, users can have mail on one and Outlook on the other.

This is a commercial choice. The SDK only needs the static catalog of whichever codes you pick.

### What license check runs before IDR (local AI)?

IDR is a third-party tunnel (`idr.to`). Billing only answers “is this user allowed to use it?”

- Same `ai_assistant` add-on as secMail local AI, or
- A separate IDR offering/seat, or
- Both (assistant add-on **and** an IDR package).

The add-in then calls `hasAddon("ai_assistant")` and/or `hasOffering("idr_personal_bundle")` before showing the IDR panel.

## 10. SDK repo layout (this repo)

Dart and JavaScript live in **this** public SDK repo. Shared contract at the root; language roots so pub and pnpm do not collide.

```
2key-billing-sdks/
  openapi/                                          # /api/v1 contract
  conformance/                                      # Dart and JS CI must both pass
  packages/dart/                                    # 2key_dart_sdk → secMail
  packages/javascript/packages/browser-sdk          # @2key/browser-sdk → Outlook, portal
  packages/javascript/catalogs/                     # @2key/catalog-* tenant seeds
  scripts/fetch-binaries.*                          # two-key CLI + native libs
```

JS stays **TypeScript**, not WASM-wrapped Rust. Dart stays FFI to `two-key-core`. They share **fixtures + OpenAPI + gate names**, not runtime code. One PR that renames a claim must fail CI unless both language tests pass.
