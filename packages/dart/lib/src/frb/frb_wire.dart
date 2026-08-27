import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Low-level C ABI loader matching `two-key-core` FRB/C exports.
///
/// Prefer [RustBillingCore] for product code.
class FrbWire {
  FrbWire._(this._lib)
      : _free = _lib.lookupFunction<_FreeNative, _FreeDart>('two_key_string_free'),
        _normalize = _lib.lookupFunction<_Str1Native, _Str1Dart>(
          'two_key_normalize_api_base_url',
        ),
        _verify = _lib.lookupFunction<_Str2Native, _Str2Dart>(
          'two_key_verify_license_json',
        ),
        _init = _lib.lookupFunction<_Str2Native, _Str2Dart>(
          'two_key_init_license_json',
        ),
        _sync = _lib.lookupFunction<_Str3Native, _Str3Dart>(
          'two_key_sync_license_json',
        ),
        _bootstrap = _lib.lookupFunction<_Str2Native, _Str2Dart>(
          'two_key_ensure_billing_context_json',
        ),
        _shouldPoll = _lib.lookupFunction<_Str2Native, _Str2Dart>(
          'two_key_should_poll_json',
        ),
        _validateConfig = _lib.lookupFunction<_Str3Native, _Str3Dart>(
          'two_key_validate_config_json',
        ),
        _cryptoGenerateKeyAndCsr = _lookupCrypto(
          _lib,
          'two_key_crypto_generate_key_and_csr_json',
        ),
        _cryptoSignClientCert = _lookupCrypto(
          _lib,
          'two_key_crypto_sign_client_cert_from_csr_json',
        ),
        _cryptoVerifyCert = _lookupCrypto(
          _lib,
          'two_key_crypto_verify_ed25519_cert_json',
        ),
        _cryptoMaterializeMtls = _lookupCrypto(
          _lib,
          'two_key_crypto_materialize_mtls_client_json',
        ),
        _cryptoSignJson = _lookupCrypto(
          _lib,
          'two_key_crypto_sign_json_b64url_json',
        );

  final DynamicLibrary _lib;
  final _FreeDart _free;
  final _Str1Dart _normalize;
  final _Str2Dart _verify;
  final _Str2Dart _init;
  final _Str3Dart _sync;
  final _Str2Dart _bootstrap;
  final _Str2Dart _shouldPoll;
  final _Str3Dart _validateConfig;
  final _Str1Dart? _cryptoGenerateKeyAndCsr;
  final _Str1Dart? _cryptoSignClientCert;
  final _Str1Dart? _cryptoVerifyCert;
  final _Str1Dart? _cryptoMaterializeMtls;
  final _Str1Dart? _cryptoSignJson;

  static _Str1Dart? _lookupCrypto(DynamicLibrary lib, String name) {
    try {
      return lib.lookupFunction<_Str1Native, _Str1Dart>(name);
    } catch (_) {
      return null;
    }
  }

  /// Load from path, `TWOKEY_CORE_LIB`, or default search paths.
  factory FrbWire.open([String? libraryPath]) {
    final path =
        libraryPath ??
        Platform.environment['TWOKEY_CORE_LIB'] ??
        _defaultLibraryPath();
    return FrbWire._(DynamicLibrary.open(path));
  }

  /// True when a native library can be resolved without opening it.
  static bool get isAvailable {
    try {
      _defaultLibraryPath();
      return true;
    } catch (_) {
      return Platform.environment['TWOKEY_CORE_LIB']?.isNotEmpty == true;
    }
  }

  static String _defaultLibraryPath() {
    final name = Platform.isWindows
        ? 'two_key_core.dll'
        : Platform.isMacOS
        ? 'libtwo_key_core.dylib'
        : 'libtwo_key_core.so';

    final candidates = <String>[
      '${Directory.current.path}${Platform.pathSeparator}bin${Platform.pathSeparator}$name',
      '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}bin${Platform.pathSeparator}$name',
    ];
    final dev = Platform.environment['TWOKEY_CORE_DEV_DIR'];
    if (dev != null && dev.isNotEmpty) {
      candidates.addAll([
        '$dev${Platform.pathSeparator}target${Platform.pathSeparator}release${Platform.pathSeparator}$name',
        '$dev${Platform.pathSeparator}target${Platform.pathSeparator}debug${Platform.pathSeparator}$name',
      ]);
    }
    for (final p in candidates) {
      if (File(p).existsSync()) return p;
    }
    throw StateError(
      'two_key_core native library not found. '
      'Run scripts/fetch-binaries or set TWOKEY_CORE_LIB / TWOKEY_CORE_DEV_DIR.',
    );
  }

  String normalizeApiBaseUrl(String input) => _call1(_normalize, input);

  Map<String, dynamic> verifyLicense(String pem, String jwt) =>
      _call2Json(_verify, pem, jwt);

  Map<String, dynamic> initLicense(String pem, String jwt) =>
      _call2Json(_init, pem, jwt);

  Map<String, dynamic> syncLicense(
    String apiBaseUrl,
    String pem,
    String sessionJson,
  ) => _call3Json(_sync, apiBaseUrl, pem, sessionJson);

  Map<String, dynamic> ensureBillingContext(
    String apiBaseUrl,
    String accessToken,
  ) => _call2Json(_bootstrap, apiBaseUrl, accessToken);

  Map<String, dynamic> shouldPoll(String pem, String? licenseJwt) {
    final pemPtr = pem.toNativeUtf8();
    final jwtPtr = licenseJwt?.toNativeUtf8();
    final outPtr = _shouldPoll(pemPtr, jwtPtr ?? nullptr);
    calloc.free(pemPtr);
    if (jwtPtr != null) calloc.free(jwtPtr);
    return _readJson(outPtr);
  }

  Map<String, dynamic> validateConfig(
    String apiBaseUrl,
    String pem,
    String storagePrefix,
  ) => _call3Json(_validateConfig, apiBaseUrl, pem, storagePrefix);

  Map<String, dynamic> cryptoGenerateKeyAndCsr(String inputJson) =>
      _call1Json(_requireCrypto(_cryptoGenerateKeyAndCsr, 'generate_key_and_csr'), inputJson);

  Map<String, dynamic> cryptoSignClientCertFromCsr(String inputJson) =>
      _call1Json(_requireCrypto(_cryptoSignClientCert, 'sign_client_cert_from_csr'), inputJson);

  Map<String, dynamic> cryptoVerifyEd25519Cert(String inputJson) =>
      _call1Json(_requireCrypto(_cryptoVerifyCert, 'verify_ed25519_cert'), inputJson);

  Map<String, dynamic> cryptoMaterializeMtlsClient(String identityJson) =>
      _call1Json(_requireCrypto(_cryptoMaterializeMtls, 'materialize_mtls_client'), identityJson);

  Map<String, dynamic> cryptoSignJsonB64Url(String inputJson) =>
      _call1Json(_requireCrypto(_cryptoSignJson, 'sign_json_b64url'), inputJson);

  _Str1Dart _requireCrypto(_Str1Dart? fn, String name) {
    if (fn == null) {
      throw StateError(
        'two_key_crypto_$name not found — upgrade to two-key-core v0.1.2+ '
        'or set TWOKEY_CORE_DEV_DIR.',
      );
    }
    return fn;
  }

  Map<String, dynamic> _call1Json(_Str1Dart fn, String a) {
    final p = a.toNativeUtf8();
    final out = fn(p);
    calloc.free(p);
    return _readJson(out);
  }

  String _call1(_Str1Dart fn, String a) {
    final p = a.toNativeUtf8();
    final out = fn(p);
    calloc.free(p);
    return _readString(out);
  }

  Map<String, dynamic> _call2Json(_Str2Dart fn, String a, String b) {
    final pa = a.toNativeUtf8();
    final pb = b.toNativeUtf8();
    final out = fn(pa, pb);
    calloc.free(pa);
    calloc.free(pb);
    return _readJson(out);
  }

  Map<String, dynamic> _call3Json(
    _Str3Dart fn,
    String a,
    String b,
    String c,
  ) {
    final pa = a.toNativeUtf8();
    final pb = b.toNativeUtf8();
    final pc = c.toNativeUtf8();
    final out = fn(pa, pb, pc);
    calloc.free(pa);
    calloc.free(pb);
    calloc.free(pc);
    return _readJson(out);
  }

  String _readString(Pointer<Utf8> outPtr) {
    if (outPtr == nullptr) {
      throw StateError('two_key_core returned null');
    }
    final s = outPtr.toDartString();
    _free(outPtr);
    return s;
  }

  Map<String, dynamic> _readJson(Pointer<Utf8> outPtr) {
    final s = _readString(outPtr);
    return jsonDecode(s) as Map<String, dynamic>;
  }
}

typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);
typedef _Str1Native = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _Str1Dart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _Str2Native = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _Str2Dart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _Str3Native =
    Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef _Str3Dart =
    Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
