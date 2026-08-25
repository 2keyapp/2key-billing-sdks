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

Native license path can use FFI against a prebuilt core binary from **`2key-core-sdk`** Releases (`scripts/fetch-binaries.*` + `TWOKEY_CORE_LIB`).

See [retire-billing-dart-sdk.md](../../docs/retire-billing-dart-sdk.md).
