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
- Use [BillingMode] on `BillingSession` for offline vs online license behavior:
  - `BillingMode.offline` — restore/verify cached license JWT only (no license HTTP).
  - `BillingMode.online` — allow `syncOnlineForAccount` / poll when entitlements exist.
- License verify/sync prefer **`two-key-core` via FRB wire** (`LicenseBackend.rustCore`) when the native lib is present; hosts must not import Rust crates. Fetch binaries with `scripts/fetch-binaries.*`.

```dart
final session = BillingSession(
  store: store,
  mode: BillingMode.online, // or BillingMode.offline
);
session.setOnline(false); // → BillingMode.offline
await BillingSdk.configureFrom(config); // rustCore when lib available
```

See [retire-billing-dart-sdk.md](retire-billing-dart-sdk.md) and `packages/dart/lib/src/frb/`.

## Browser / SPA

TypeScript / browser product SDK: **[`2key-browser-sdk`](https://github.com/2keyapp/2key-browser-sdk)** (`@2key/browser-sdk`).

```ts
import { acquireApiToken, verifyLicenseJwt, authorize } from "@2key/browser-sdk";
```

See that repo’s `docs/host-integration.md` and `docs/portal-migration.md`.

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
