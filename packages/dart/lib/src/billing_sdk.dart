import 'dart:convert';

import 'package:two_key_dart_sdk/src/api/billing_api_client.dart';
import 'package:two_key_dart_sdk/src/catalog/plan_catalog.dart';
import 'package:two_key_dart_sdk/src/config/billing_sdk_config.dart';
import 'package:two_key_dart_sdk/src/frb/rust_billing_core.dart';
import 'package:two_key_dart_sdk/src/keys/default_public_key.dart';
import 'package:two_key_dart_sdk/src/keys/public_key_loader.dart';
import 'package:two_key_dart_sdk/src/keys/public_key_loader_asset.dart';
import 'package:two_key_dart_sdk/src/models/billing_stats.dart';
import 'package:two_key_dart_sdk/src/models/billing_token_error.dart';
import 'package:two_key_dart_sdk/src/models/billing_token_payload.dart';
import 'package:two_key_dart_sdk/src/verification/token_verifier.dart';

/// Client SDK for **using-party apps**: auth token → license sync → offline entitlements.
///
/// License verify/sync prefer [LicenseBackend.rustCore] (`two-key-core` via FRB
/// wire) when the native library is present; otherwise pure Dart.
///
/// Use [BillingAuthClient] for login and [BillingSession] for persisted state.
class BillingSdk {
  BillingSdk._();

  static String? _billingApiBaseUrl;
  static String? _publicKeyPem;
  static TokenVerifier? _verifier;
  static BillingApiClient? _apiClient;
  static BillingSdkConfig? _config;
  static RustBillingCore? _rust;

  static BillingTokenPayload? _currentPayload;
  static String? _loadedKeyFingerprint;

  static String? get loadedKeyFingerprint => _loadedKeyFingerprint;

  /// Last config applied via [configureFrom], if any.
  static BillingSdkConfig? get config => _config;

  /// Active license backend after [configure] / [configureFrom].
  static LicenseBackend get licenseBackend => RustBillingCore.resolveBackend();

  static String _pemFingerprint(String pem) {
    const begin = '-----BEGIN PUBLIC KEY-----';
    const end = '-----END PUBLIC KEY-----';
    final start = pem.indexOf(begin);
    final endIdx = pem.indexOf(end);
    if (start < 0 || endIdx <= start) return '?';
    final body = pem
        .substring(start + begin.length, endIdx)
        .replaceAll(RegExp(r'\s'), '');
    return body.length >= 24 ? body.substring(body.length - 24) : body;
  }

  static void configure({
    String? billingApiBaseUrl,
    String? publicKeyPem,
    String? publicKeyPath,
    LicenseBackend? licenseBackend,
  }) {
    if (licenseBackend != null) {
      RustBillingCore.preferredBackend = licenseBackend;
    }
    if (billingApiBaseUrl != null) _billingApiBaseUrl = billingApiBaseUrl;
    if (publicKeyPem != null) {
      _publicKeyPem = publicKeyPem;
      _loadedKeyFingerprint = _pemFingerprint(publicKeyPem);
    }
    if (publicKeyPath != null && publicKeyPath.trim().isNotEmpty) {
      _publicKeyPem = loadPublicKeyFromPath(publicKeyPath.trim());
      _loadedKeyFingerprint = _pemFingerprint(_publicKeyPem!);
    }
    _verifier = null;
    _apiClient = null;
    _rust = RustBillingCore.tryOpen();
  }

  /// Applies [BillingSdkConfig] (API base URL + license public key).
  static Future<void> configureFrom(
    BillingSdkConfig config, {
    LicenseBackend? licenseBackend,
  }) async {
    _config = config;
    var pem = config.publicKeyPem?.trim();
    if ((pem == null || pem.isEmpty) &&
        config.publicKeyAsset != null &&
        config.publicKeyAsset!.trim().isNotEmpty) {
      pem = await loadPublicKeyFromAsset(config.publicKeyAsset!.trim());
    }
    if (pem == null || pem.isEmpty) {
      throw StateError(
        'BillingSdk.configureFrom: provide publicKeyPem or publicKeyAsset.',
      );
    }
    configure(
      billingApiBaseUrl: config.apiBaseUrl,
      publicKeyPem: pem,
      licenseBackend: licenseBackend,
    );
  }

  static Future<void> configureWithAsset({
    String? billingApiBaseUrl,
    required String publicKeyAsset,
  }) async {
    final pem = await loadPublicKeyFromAsset(publicKeyAsset);
    configure(billingApiBaseUrl: billingApiBaseUrl, publicKeyPem: pem);
  }

  /// Test-only configure that installs the SDK unit-test public key when
  /// [publicKeyPem] is omitted. Production hosts must use [configure] /
  /// [configureFrom] with their real license public key.
  static void configureForTesting({
    String? billingApiBaseUrl,
    String? publicKeyPem,
    LicenseBackend licenseBackend = LicenseBackend.pureDart,
  }) {
    configure(
      billingApiBaseUrl: billingApiBaseUrl,
      publicKeyPem: publicKeyPem ?? defaultPublicKeyPem,
      licenseBackend: licenseBackend,
    );
  }

  static void resetForTesting() {
    _billingApiBaseUrl = null;
    _publicKeyPem = null;
    _verifier = null;
    _apiClient = null;
    _currentPayload = null;
    _loadedKeyFingerprint = null;
    _config = null;
    _rust = null;
    RustBillingCore.resetForTesting();
  }

  static String? getJwtAlg(String signedToken) {
    try {
      final parts = signedToken.trim().split('.');
      if (parts.length < 2) return null;
      final raw = parts[0].replaceAll('-', '+').replaceAll('_', '/');
      final pad = raw.length % 4;
      final padded = pad == 2 ? '$raw==' : pad == 3 ? '$raw=' : raw;
      final map =
          jsonDecode(utf8.decode(base64Url.decode(padded)))
              as Map<String, dynamic>?;
      return map?['alg'] as String?;
    } catch (_) {
      return null;
    }
  }

  static String get _pemOrThrow {
    final pem = _publicKeyPem;
    if (pem == null || pem.trim().isEmpty) {
      throw StateError(
        'BillingSdk: call configure(...) or configureFrom(...) with a '
        'license public key before verifying tokens.',
      );
    }
    return pem;
  }

  static TokenVerifier get _verifierOrThrow {
    return _verifier ??= TokenVerifier(publicKeyPem: _pemOrThrow);
  }

  static BillingApiClient get _apiClientOrThrow {
    final base = _billingApiBaseUrl;
    if (base == null || base.isEmpty) {
      throw StateError(
        'BillingSdk: call configure(billingApiBaseUrl: ...) before API calls.',
      );
    }
    return _apiClient ??= BillingApiClient(baseUrl: base);
  }

  static RustBillingCore? get _rustIfActive {
    if (RustBillingCore.resolveBackend() != LicenseBackend.rustCore) {
      return null;
    }
    return _rust ??= RustBillingCore.tryOpen();
  }

  static void init(String? savedSignedJson) {
    if (savedSignedJson == null || savedSignedJson.trim().isEmpty) {
      _currentPayload = null;
      return;
    }
    final result = verifyAndDecode(savedSignedJson.trim());
    switch (result) {
      case VerifySuccess(:final payload):
        _currentPayload = payload;
      case VerifyFailure():
        _currentPayload = null;
    }
  }

  static BillingTokenPayload? getPayload() => _currentPayload;

  static Future<SyncResult> syncFromServer({
    required String authorizationToken,
    String? payingPartyId,
    String? ifNoneMatch,
    String? accountKey,
    String? cachedLicenseJwt,
  }) async {
    final base = _billingApiBaseUrl;
    if (base == null || base.isEmpty) {
      throw StateError(
        'BillingSdk: call configure(billingApiBaseUrl: ...) before API calls.',
      );
    }

    final rust = _rustIfActive;
    if (rust != null) {
      final session = <String, dynamic>{
        'account_key': accountKey ?? 'default',
        'access_token': authorizationToken,
        'license_jwt': cachedLicenseJwt,
        'license_etag': ifNoneMatch,
        'paying_party_id_header': payingPartyId,
      };
      final outcome = rust.syncLicense(
        apiBaseUrl: base,
        publicKeyPem: _pemOrThrow,
        session: session,
      );
      switch (outcome) {
        case RustSyncUpdated(:final session, :final payload):
          if (payload != null) _currentPayload = payload;
          final jwt = session['license_jwt'] as String?;
          if (jwt == null || jwt.isEmpty) {
            return const SyncFailure(message: 'Rust sync returned empty JWT');
          }
          return SyncSuccess(
            signedToken: jwt,
            etag: session['license_etag'] as String?,
          );
        case RustSyncNotModified(:final session, :final payload):
          if (payload != null) _currentPayload = payload;
          return SyncNotModified(etag: session['license_etag'] as String?);
        case RustSyncFailure(:final message):
          return SyncFailure(message: message);
      }
    }

    final result = await _apiClientOrThrow.fetchLicense(
      authorizationToken: authorizationToken,
      payingPartyId: payingPartyId,
      ifNoneMatch: ifNoneMatch,
    );
    switch (result) {
      case SyncNotModified():
        return result;
      case SyncSuccess(:final signedToken):
        final verifyResult = _verifierOrThrow.verifyAndDecode(signedToken);
        switch (verifyResult) {
          case VerifySuccess(:final payload):
            _currentPayload = payload;
            return result;
          case VerifyFailure(:final error):
            return SyncFailure(message: error.message);
        }
      case SyncFailure():
        return result;
    }
  }

  static Future<BootstrapResult> ensureBillingContext({
    required String authorizationToken,
  }) async {
    final rust = _rustIfActive;
    if (rust != null) {
      final base = _billingApiBaseUrl;
      if (base == null || base.isEmpty) {
        return const BootstrapFailure(
          message: 'BillingSdk: configure billingApiBaseUrl before bootstrap.',
        );
      }
      final json = rust.ensureBillingContextRaw(
        apiBaseUrl: base,
        accessToken: authorizationToken,
      );
      if (json['ok'] != true) {
        return BootstrapFailure(
          message: json['message'] as String? ?? 'Bootstrap failed',
        );
      }
      try {
        final data = json['data'];
        final map = _asStringKeyedMap(data) ?? <String, dynamic>{};
        // Nested maps from FFI JSON may be Map<dynamic, dynamic>.
        final normalized = _normalizeJsonMap(map);
        return BootstrapSuccess(PayingPartyBillingStats.fromJson(normalized));
      } catch (e) {
        return BootstrapFailure(message: 'Invalid bootstrap payload: $e');
      }
    }
    return _apiClientOrThrow.ensureBillingContext(
      authorizationToken: authorizationToken,
    );
  }

  static Future<PayingPartyBillingStats> fetchBillingStats({
    required String authorizationToken,
  }) async {
    final result = await ensureBillingContext(
      authorizationToken: authorizationToken,
    );
    if (result is BootstrapSuccess) return result.stats;
    throw StateError((result as BootstrapFailure).message);
  }

  /// Public monthly + annual plan catalog for in-app pricing UI.
  static Future<PlanCatalog> fetchPlanCatalog({
    int? productId,
    bool includeInactive = false,
  }) => PlanCatalog.load(
    _apiClientOrThrow,
    productId: productId,
    includeInactive: includeInactive,
  );

  static VerifyResult verifyAndDecode(String pastedJson) {
    final trimmed = pastedJson.trim();
    final rust = _rustIfActive;
    final VerifyResult result;
    if (rust != null) {
      result = rust.verifyLicense(publicKeyPem: _pemOrThrow, jwt: trimmed);
    } else {
      result = _verifierOrThrow.verifyAndDecode(trimmed);
    }
    if (result case VerifySuccess(:final payload)) {
      _currentPayload = payload;
    }
    return result;
  }

  static Map<String, dynamic>? _asStringKeyedMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static Map<String, dynamic> _normalizeJsonMap(Map<String, dynamic> input) {
    final out = <String, dynamic>{};
    for (final e in input.entries) {
      final v = e.value;
      if (v is Map) {
        out[e.key] = _normalizeJsonMap(Map<String, dynamic>.from(v));
      } else if (v is List) {
        out[e.key] = v.map((item) {
          if (item is Map) {
            return _normalizeJsonMap(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        out[e.key] = v;
      }
    }
    return out;
  }
}
