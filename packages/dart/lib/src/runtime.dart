import 'errors.dart';
import 'ffi_core.dart';
import 'license.dart' as dart_license;

/// Dual-path backend selection for license/session logic.
///
/// `pureDart` — Dart `dart_jsonwebtoken` implementation.
/// `rustCore` — `dart:ffi` → `two_key_core` C ABI (FRB precursor).
enum LicenseBackend {
  pureDart,
  rustCore,
}

/// Global toggle for dual-path experiments (default pure Dart).
class TwoKeyRuntime {
  TwoKeyRuntime._();

  static LicenseBackend licenseBackend = LicenseBackend.pureDart;

  static TwoKeyCoreFfi? _ffi;

  /// Optional explicit native library path (otherwise TWOKEY_CORE_LIB / cargo target).
  static String? nativeLibraryPath;

  /// Drop cached [DynamicLibrary] (tests / path changes).
  static void resetFfi() {
    _ffi = null;
  }

  /// Whether Rust path can be used (loads cdylib lazily).
  static void ensureBackendAvailable() {
    if (licenseBackend == LicenseBackend.rustCore) {
      _ffi ??= TwoKeyCoreFfi.open(nativeLibraryPath);
    }
  }

  static TwoKeyCoreFfi get ffi {
    ensureBackendAvailable();
    return _ffi!;
  }
}

/// Verify license JWT using the active [TwoKeyRuntime.licenseBackend].
dart_license.LicensePayload verifyLicenseJwt(String token, String publicKeyPem) {
  TwoKeyRuntime.ensureBackendAvailable();
  switch (TwoKeyRuntime.licenseBackend) {
    case LicenseBackend.pureDart:
      return dart_license.verifyLicenseJwt(token, publicKeyPem);
    case LicenseBackend.rustCore:
      try {
        return TwoKeyRuntime.ffi.verifyLicenseJwt(token, publicKeyPem);
      } on TwoKeyException {
        rethrow;
      } catch (e) {
        throw TwoKeyException(
          TwoKeyErrorCode.unknown,
          'Rust FFI verify failed',
          detail: '$e',
        );
      }
  }
}
