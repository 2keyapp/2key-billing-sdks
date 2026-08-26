import 'dart:convert';

import '../api/billing_api_client.dart';
import '../models/billing_token_error.dart';
import '../models/billing_token_payload.dart';
import 'frb_wire.dart';

/// Product adapter over private `two-key-core` (FRB / C ABI wire).
///
/// Offline: [verifyLicense] / [initLicense].
/// Online: [ensureBillingContextRaw] + [syncLicense].
///
/// Hosts must ship or fetch the native library (`scripts/fetch-binaries` /
/// `TWOKEY_CORE_LIB` / `TWOKEY_CORE_DEV_DIR`).
class RustBillingCore {
  RustBillingCore._(this._wire);

  final FrbWire _wire;

  static RustBillingCore? _instance;

  /// Opens (or returns) the shared native core when available.
  static RustBillingCore? tryOpen([String? libraryPath]) {
    if (_instance != null) return _instance;
    try {
      _instance = RustBillingCore._(FrbWire.open(libraryPath));
      return _instance;
    } catch (_) {
      return null;
    }
  }

  /// Force-open; throws if the native library is missing.
  factory RustBillingCore.open([String? libraryPath]) {
    return _instance ??= RustBillingCore._(FrbWire.open(libraryPath));
  }

  /// Production path: native core is required.
  static RustBillingCore require([String? libraryPath]) {
    final core = tryOpen(libraryPath);
    if (core == null) {
      throw StateError(
        'two_key_core native library is required. '
        'Run scripts/fetch-binaries or set TWOKEY_CORE_LIB / TWOKEY_CORE_DEV_DIR.',
      );
    }
    return core;
  }

  static void resetForTesting() {
    _instance = null;
  }

  String normalizeApiBaseUrl(String input) => _wire.normalizeApiBaseUrl(input);

  VerifyResult verifyLicense({
    required String publicKeyPem,
    required String jwt,
  }) {
    final json = _wire.verifyLicense(publicKeyPem, jwt);
    return _verifyResultFromJson(json);
  }

  VerifyResult initLicense({
    required String publicKeyPem,
    required String jwt,
  }) {
    final json = _wire.initLicense(publicKeyPem, jwt);
    return _verifyResultFromJson(json);
  }

  /// Online sync. [session] keys use snake_case matching Rust AccountSession.
  RustSyncOutcome syncLicense({
    required String apiBaseUrl,
    required String publicKeyPem,
    required Map<String, dynamic> session,
  }) {
    final json = _wire.syncLicense(
      apiBaseUrl,
      publicKeyPem,
      jsonEncode(session),
    );
    if (json['ok'] != true) {
      return RustSyncFailure(
        code: json['code'] as String? ?? 'unknown',
        message: json['message'] as String? ?? 'License sync failed',
      );
    }
    final status = json['status'] as String? ?? 'updated';
    final sessionOut = Map<String, dynamic>.from(
      json['session'] as Map? ?? const {},
    );
    final claims = json['claims'];
    BillingTokenPayload? payload;
    if (claims is Map) {
      try {
        payload = BillingTokenPayload.fromJson(
          Map<String, dynamic>.from(claims),
        );
      } catch (_) {
        payload = null;
      }
    }
    if (status == 'not_modified') {
      return RustSyncNotModified(session: sessionOut, payload: payload);
    }
    return RustSyncUpdated(session: sessionOut, payload: payload);
  }

  /// Bootstrap `subscriptions/me` JSON (`ok` + `data`).
  Map<String, dynamic> ensureBillingContextRaw({
    required String apiBaseUrl,
    required String accessToken,
  }) => _wire.ensureBillingContext(apiBaseUrl, accessToken);

  bool shouldPoll({required String publicKeyPem, String? licenseJwt}) {
    final json = _wire.shouldPoll(publicKeyPem, licenseJwt);
    return json['should_poll'] == true;
  }

  static VerifyResult _verifyResultFromJson(Map<String, dynamic> json) {
    if (json['ok'] == true) {
      final claims = json['claims'];
      if (claims is Map) {
        try {
          return VerifySuccess(
            BillingTokenPayload.fromJson(Map<String, dynamic>.from(claims)),
          );
        } on FormatException catch (e) {
          return VerifyFailure(
            BillingTokenError(
              message: e.message,
              reason: BillingTokenErrorReason.missingClaims,
            ),
          );
        }
      }
      return VerifyFailure(
        BillingTokenError(
          message: 'License verified but claims missing',
          reason: BillingTokenErrorReason.missingClaims,
        ),
      );
    }
    final code = json['code'] as String? ?? 'license_invalid';
    final message = json['message'] as String? ?? 'License invalid';
    return VerifyFailure(
      BillingTokenError(message: message, reason: _reasonFromCode(code)),
    );
  }

  static BillingTokenErrorReason _reasonFromCode(String code) {
    switch (code) {
      case 'license_expired':
        return BillingTokenErrorReason.expired;
      case 'license_malformed':
        return BillingTokenErrorReason.malformed;
      case 'license_invalid':
        return BillingTokenErrorReason.invalidSignature;
      default:
        return BillingTokenErrorReason.invalidSignature;
    }
  }
}

sealed class RustSyncOutcome {
  const RustSyncOutcome();
}

class RustSyncUpdated extends RustSyncOutcome {
  const RustSyncUpdated({required this.session, this.payload});
  final Map<String, dynamic> session;
  final BillingTokenPayload? payload;
}

class RustSyncNotModified extends RustSyncOutcome {
  const RustSyncNotModified({required this.session, this.payload});
  final Map<String, dynamic> session;
  final BillingTokenPayload? payload;
}

class RustSyncFailure extends RustSyncOutcome {
  const RustSyncFailure({required this.code, required this.message});
  final String code;
  final String message;
}
