# Host integration — depend only on `2key_<lang>_sdk`

Host apps (Scomm, secMail, billing-portal, CLI consumers) must **never** depend
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

See [retire-billing-dart-sdk.md](retire-billing-dart-sdk.md).

## Browser / SPA (billing-portal)

```bash
npm install @2key/ts-sdk
# or git dependency on this monorepo path packages/ts until published
```

```ts
import {
  BillingApiClient,
  acquireApiToken,
  verifyLicenseJwt,
  portalHandoffUrl,
  shopUrl,
} from "@2key/ts-sdk";
```

Typical browser flow:

1. Better Auth cookie session via redirect (`socialSignInUrl` / host auth client).
2. `acquireApiToken(config)` → billing JWT (`aud=billing`).
3. `BillingApiClient.ensureBillingContext` / `fetchLicense` / `fetchPlans`.
4. `verifyLicenseJwt` offline with the public PEM.
5. Portal handoff from native: `portalHandoffUrl` + OTT from auth host.

The SPA must **not** import `better-auth` server plugins or private core binaries.
Auth client usage stays behind portal code or a thin wrapper; prefer SDK helpers
above for `/api/v1` and license verify.

See [portal-migration.md](portal-migration.md) and [auth-protocol.md](auth-protocol.md).

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
4. In `packages/dart` pubspec: set `path: packages/clients/dart` and pin the new SHA (until then keep `packages/flutter/dart` at the last pre-move SHA).
