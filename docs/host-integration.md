# Host integration — depend only on `2key_<lang>_sdk`

Host apps (Scomm, secMail, billing-portal, Outlook, CLI consumers) must **never** depend
directly on Better Auth, `two-key-core` Rust source, or `@2key/billing-core`.

## Dart / Flutter

```yaml
dependencies:
  two_key_dart_sdk:
    git:
      url: https://github.com/2keyapp/2key-billing-sdks.git
      path: packages/dart
      ref: <PINNED_SHA>
```

```dart
import 'package:two_key_dart_sdk/two_key_dart_sdk.dart';
// Temporary alias during cutover:
// import 'package:two_key_dart_sdk/billing_dart_sdk.dart';
```

Rules:

- Do **not** add `better_auth` to the host `pubspec.yaml`.
- Do **not** set `TWOKEY_CORE_DEV_DIR` in production builds (dev-only).
- Supply `AuthSessionLauncher` + secure storage adapters; keep OAuth UI in the app.
- Prefer instance APIs; static `BillingSdk` remains for compatibility.
- Use [BillingMode] on `BillingSession` for offline vs online license behavior:
  - `BillingMode.offline` — restore/verify cached license JWT only (no license HTTP).
  - `BillingMode.online` — allow `syncOnlineForAccount` / poll when entitlements exist.
- License verify/sync/bootstrap **require** `two-key-core` via FRB wire (`RustBillingCore`). Hosts must not import Rust crates. Fetch binaries with `scripts/fetch-binaries.*` (or `TWOKEY_CORE_LIB` / `TWOKEY_CORE_DEV_DIR` for local builds).

```dart
final session = BillingSession(
  store: store,
  mode: BillingMode.online, // or BillingMode.offline
);
session.setOnline(false); // → BillingMode.offline
await BillingSdk.configureFrom(config); // rustCore when lib available
```

See [retire-billing-dart-sdk.md](retire-billing-dart-sdk.md) and `packages/dart/lib/src/frb/`.

## Browser / SPA (billing-portal)

```bash
pnpm add @2key/browser-sdk
# until published:
pnpm add github:2keyapp/2key-billing-sdks#path:packages/javascript/packages/browser-sdk
```

```ts
import {
  BillingApiClient,
  acquireApiToken,
  verifyLicenseJwt,
  portalHandoffUrl,
  shopUrl,
  authorize,
} from "@2key/browser-sdk";
```

Typical browser flow:

1. Better Auth cookie session via redirect (`socialSignInUrl` / host auth client).
2. `acquireApiToken(config)` → billing JWT (`aud=billing`).
3. `BillingApiClient.ensureBillingContext` / `fetchLicense` / `fetchPlans`.
4. `verifyLicenseJwt` offline with the public PEM.
5. Portal handoff from native: `portalHandoffUrl` + OTT from auth host.
6. AuthZ: `authorize` / `enforceLocally` before privileged client actions (server always re-checks).

The SPA must **not** import `better-auth` server plugins or private core binaries.

See [portal-migration.md](portal-migration.md) and [auth-protocol.md](auth-protocol.md).

## Outlook add-in (Office.js)

SComm Outlook is a **JS host** of `@2key/browser-sdk`. The JS SDK must match
`2key_dart_sdk` for DeviceID, signed license populate, and product gates.
See [office-add-in-embed.md](office-add-in-embed.md).

Production add-in origin: `https://office.scomm.ai`.

```ts
import {
  createBillingClient,
  acquireApiToken,
  signInWithEmail,
  fetchOAuthProviders,
} from "@2key/browser-sdk";

const billing = createBillingClient({
  apiBaseUrl,
  publicKeyPem,
  storagePrefix: "scomm-office",
  catalog: { productIds: ["prod_mail"], offeringCodes: ["ai_assistant"], addonCodes: ["ai_assistant"] },
});
await billing.ensureDeviceId();
await billing.restore();
await billing.syncLicense({ accessToken });
if (!billing.hasProduct("prod_mail")) { /* locked */ }
```

## CLI / ops

```bash
./scripts/fetch-binaries.sh   # or .ps1 on Windows
./bin/two-key version
```

Pins and checksums: `core-binaries.lock.json`. Source stays in private `2key-core-sdk`.

## Forbidden

| Dependency | Why |
|------------|-----|
| `package:better_auth` in host apps | Auth client is internal to `two_key_dart_sdk` |
| `@better-auth/*` / `@2key/auth-native` in SPA product code | Server plugin / fork — not a browser product SDK |
| `cargo` path dep on `two-key-core` | Binary Private Core — fetch release libs only |
| `@2key/billing-core` | Private server package |

## After Phase 5 push (better-auth)

1. Push `better-auth` (`packages/native`, `packages/clients/dart`, upstream-sync).
2. Run `pnpm run release:branch` in the fork (publishes `#release-native`).
3. In `2key-billing`: refresh lockfile for `@2key/auth-native`.
4. In `packages/dart` pubspec: set Better Auth `path: packages/clients/dart` and pin the new SHA (until then keep `packages/flutter/dart` at the last pre-move SHA).
