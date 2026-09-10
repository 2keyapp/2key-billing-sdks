# @2key/browser-sdk

Unified **browser** client SDK for 2key — **AuthN + AuthZ + Billing**.

This package lives in the **`2key-billing-sdks`** polyglot repo (`packages/javascript/packages/browser-sdk`).
Native parity lives in private [`2key-core-sdk`](https://github.com/2keyapp/2key-core-sdk) (Rust: `two-key-core`, `dp-rust*`).
Dart parity lives in `packages/dart` (`two_key_dart_sdk`) — same OpenAPI and conformance fixtures.

## Install

```bash
pnpm add @2key/browser-sdk
```

## Imports

```ts
// Full surface
import { createBillingClient, acquireApiToken, signInWithEmail, authorize } from "@2key/browser-sdk";

// Pillars
import { acquireApiToken, signInWithEmail, socialSignInUrl } from "@2key/browser-sdk/auth";
import { createBillingClient, verifyLicenseJwt } from "@2key/browser-sdk/billing";
import { authorize, enforceLocally } from "@2key/browser-sdk/authorize";
import { createAdminClient, createMachineAuthnClient } from "@2key/browser-sdk/dp";
```

```ts
import { catalogForHost, createBillingClient } from "@2key/browser-sdk";
import hosts from "./hosts.json";

const billing = createBillingClient({
  apiBaseUrl: "https://billing.example.com",
  publicKeyPem,
  storagePrefix: "my-app",
  catalog: catalogForHost(hosts, "<hostKey>"),
});

await billing.ensureDeviceId({ friendlyName: "Office WebView" });
await billing.restore();
await billing.syncLicense({ accessToken });
if (!billing.hasProduct("<productName>")) {
  /* locked */
}
const seats = billing.hostSubscriptions();
```

Bake **this tenant’s** `hosts.json` at build time. `catalogForHost(hosts, hostKey)` picks one slice from that file. Product identity is a catalog name, not a Postgres serial id. The SDK has no built-in tenant catalog.

Gates and seat lists use `billing.entitlements()` / `hostSubscriptions()` (`catalog ∩ JWT`). Do not iterate `restore()` / `payload.subscriptions` for UI — that list is the full identity JWT. Device bind still uses the raw JWT.

## Pillars

| Pillar | Role | Native counterpart |
|--------|------|--------------------|
| **AuthN** | Cookie / redirect adapters to Better Auth host | Dart/`@2key/auth-native` transport |
| **Billing** | License verify/sync, session, plans, usage | `two-key-core` |
| **AuthZ** | Capability algebra + DP / Machine AuthN HTTP | `dp-rust` / `dp-rust-sdk` |

Apps import this package only — never Better Auth types or private Rust source.
