# Retire `billing_dart_sdk` (early)

**Decision:** Canonical Dart/Flutter SDK is **`2key-billing-sdks/packages/dart`** (`two_key_dart_sdk` / `2key_dart_sdk`).  
Standalone repo **`billing_dart_sdk` is frozen** and will be archived after host cutover.

## Why early

- Binary Private Core + public monorepo are the distribution model; a second Dart tree diverges.
- CLI-first public surface and shared OpenAPI/fixtures already live in `2key-billing-sdks`.
- Scomm/secMail should depend on one package path.

## Cutover steps

1. **Hosts** change `pubspec.yaml`:

   ```yaml
   dependencies:
     two_key_dart_sdk:
       git:
         url: https://github.com/2keyapp/2key-billing-sdks.git
         path: packages/dart
         ref: <PINNED_SHA>
   ```

2. Update imports:

   ```dart
   // before
   import 'package:billing_dart_sdk/billing_dart_sdk.dart';
   // after
   import 'package:two_key_dart_sdk/two_key_dart_sdk.dart';
   // temporary alias still available:
   import 'package:two_key_dart_sdk/billing_dart_sdk.dart';
   ```

3. Remove any direct `better_auth` dependency from the host (keep it internal to the SDK).

4. After Scomm/secMail + other hosts are green: archive `billing_dart_sdk` GitHub repo (read-only) and delete local checkouts from day-to-day workspaces.

## Compatibility

- `packages/dart` includes production sources migrated from `billing_dart_sdk` plus FFI dual-path toward private `two-key-core` binaries.
- API type names (`BillingAuthClient`, `BillingSession`, …) stay for a deprecation window; prefer `TwoKey*` aliases as they land.

## Do not

- Land new features only in `billing_dart_sdk`.
- Publish `billing_dart_sdk` to pub.dev.
- Reintroduce `two-key-core` Rust source into this public monorepo.
