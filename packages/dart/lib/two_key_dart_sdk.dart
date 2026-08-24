/// 2key Billing Dart SDK — host apps import this package only.
///
/// Dual-path: [LicenseBackend.pureDart] (default) or [LicenseBackend.rustCore]
/// via `dart:ffi` → `two_key_core` (set `TWOKEY_CORE_LIB` or build cargo target).
library;

export 'src/config.dart';
export 'src/errors.dart';
export 'src/license.dart' hide verifyLicenseJwt;
export 'src/api_client.dart';
export 'src/url.dart';
export 'src/session.dart';
export 'src/portal.dart';
export 'src/runtime.dart';
export 'src/ffi_core.dart' show TwoKeyCoreFfi;
