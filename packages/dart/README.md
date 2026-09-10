# 2key_dart_sdk (`two_key_dart_sdk`)

Canonical Flutter/Dart SDK for 2key Billing. **Replaces `billing_dart_sdk`.**

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
// temporary:
import 'package:two_key_dart_sdk/billing_dart_sdk.dart';
```

Host apps depend on **this package only** — never `better_auth` or private `two-key-core` source.

Pass an optional [`OfferingCatalog`](lib/src/catalog/offering_catalog.dart) in `BillingSdkConfig.catalog` so `hasProduct` / `hasOffering` / `hasAddon` and `BillingSdk.hostSubscriptions()` are fail-closed against the offerings this binary knows. Bake **this tenant’s** `hosts.json` and pass `HostsCatalog.fromJson(...).forHost('<hostKey>')`. The SDK does not ship a product catalog. Gates and seat UI must use `BillingSdk.entitlements()` / `hostSubscriptions()`, not `payload.subscriptions` (raw JWT for device bind only). Device bind: `LicenseDeviceKeystore.ensureForAccount` then `BillingApiClient.bindLicenseDevice` / `listLicenseDevices` / `revokeLicenseDevice`.

Native license path can use FFI against a prebuilt core binary from **`2key-core-sdk`** Releases (`scripts/fetch-binaries.*` + `TWOKEY_CORE_LIB`).

See [retire-billing-dart-sdk.md](../../docs/retire-billing-dart-sdk.md).
