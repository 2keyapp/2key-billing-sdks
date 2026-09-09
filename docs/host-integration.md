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
- Default [BillingMode] is `offline`. Using-party hosts (Scomm Email, Outlook) must not
  call `GET /api/v1/license` or Better Auth just to license the app.
  - `BillingMode.offline` (default) — restore/verify a pasted signed snapshot (no license HTTP).
  - `BillingMode.online` — kept compiled; `syncOnlineForAccount` / poll may be re-enabled later.
- Copy DeviceID with `LicenseDeviceIdentity.exportPasteJson()` (`friendlyName` + `publicJwk` only).
  Bind and issue in the portal (Settings → Devices). Paste the signed snapshot back.
  The snapshot has **no license TTL**; regenerate from the portal when any included
  `subscriptions[].valid_until` is past. X.509 is not the license format.
- License offline verify uses `two-key-core` via FRB when the native library is loaded,
  otherwise Dart ES256. Hosts must not import Rust crates. Fetch binaries with
  `scripts/fetch-binaries.*` (or `TWOKEY_CORE_LIB` / `TWOKEY_CORE_DEV_DIR` for local builds).

```dart
final session = BillingSession(store: store); // BillingMode.offline
await BillingSdk.configureFrom(config);
final identity = await keystore.ensureForAccount(accountKey);
final paste = identity.copyWith(friendlyName: 'secMail').exportPasteJson();
// User binds paste JSON in the portal, then:
await session.verifyOfflineToken(accountKey: accountKey, token: pastedSnapshot);
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

Typical **paying-party portal** flow:

1. Better Auth cookie session via redirect (`socialSignInUrl` / host auth client).
2. `acquireApiToken(config)` — on `orgPickRequired` / `ORG_SLUG_REQUIRED`, bind `me` or a company slug in the portal UI, then remint.
3. Bind devices and **issue** a signed snapshot (`POST /api/v1/license` or bind with `issueLicense`). Do not call `GET /api/v1/license` for using-party clients.
4. `verifyLicenseJwt` offline with the public PEM (no JWT `exp` required; reject if any `valid_until` is past).
5. Portal handoff from native: `portalHandoffUrl` + OTT from auth host. Hosts must pass `portalBaseUrl` (or open the configured portal URL) — never derive the portal from the billing API origin alone.
6. AuthZ: `authorize` / `enforceLocally` before privileged client actions (server always re-checks).

**Using-party** (secMail, Outlook): do **not** use Better Auth for licensing. DeviceID → copy paste JSON → portal Settings → Devices → paste signed snapshot → `restore()` / `pasteLicense()`. Public `GET /api/v1/plans` may still be used for shop CTAs without a user token.

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
} from "@2key/browser-sdk";

const billing = createBillingClient({
  apiBaseUrl,
  publicKeyPem,
  storagePrefix: "scomm-office",
  catalog: { productIds: ["prod_mail"], offeringCodes: ["ai_assistant"], addonCodes: ["ai_assistant"] },
});
const pasteJson = await billing.exportDevicePaste({ friendlyName: "Outlook" });
await billing.restore();
await billing.pasteLicense(snapshotFromPortal);
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
