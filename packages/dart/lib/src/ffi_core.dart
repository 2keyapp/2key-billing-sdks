/// Compatibility shim — prefer `package:two_key_dart_sdk/src/frb/frb.dart`.
library;

import 'frb/frb_wire.dart';

export 'frb/rust_billing_core.dart'
    show
        LicenseBackend,
        RustBillingCore,
        RustSyncOutcome,
        RustSyncUpdated,
        RustSyncNotModified,
        RustSyncFailure;
export 'frb/frb_wire.dart' show FrbWire;

/// Legacy wrapper around [FrbWire] for existing call sites / tests.
class TwoKeyCoreFfi {
  TwoKeyCoreFfi._(this._wire);
  final FrbWire _wire;

  factory TwoKeyCoreFfi.open([String? libraryPath]) =>
      TwoKeyCoreFfi._(FrbWire.open(libraryPath));

  String normalizeApiBaseUrl(String input) => _wire.normalizeApiBaseUrl(input);

  Map<String, dynamic> verifyLicenseJwtJson(String jwt, String publicKeyPem) =>
      _wire.verifyLicense(publicKeyPem, jwt);
}

/// Legacy exception type.
class TwoKeyFfiException implements Exception {
  TwoKeyFfiException(this.code, this.message, {this.detail});

  final String code;
  final String message;
  final String? detail;

  @override
  String toString() =>
      'TwoKeyFfiException($code): $message${detail != null ? ' ($detail)' : ''}';
}
