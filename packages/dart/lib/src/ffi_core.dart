import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'errors.dart';
import 'license.dart';

typedef _VerifyNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _VerifyDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);
typedef _NormalizeNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _NormalizeDart = Pointer<Utf8> Function(Pointer<Utf8>);

/// Low-level bindings to `two_key_core` cdylib (C ABI).
class TwoKeyCoreFfi {
  TwoKeyCoreFfi._(this._lib)
      : _verify = _lib
            .lookupFunction<_VerifyNative, _VerifyDart>('two_key_verify_license_json'),
        _free = _lib.lookupFunction<_FreeNative, _FreeDart>('two_key_string_free'),
        _normalize = _lib.lookupFunction<_NormalizeNative, _NormalizeDart>(
          'two_key_normalize_api_base_url',
        );

  final DynamicLibrary _lib;
  final _VerifyDart _verify;
  final _FreeDart _free;
  final _NormalizeDart _normalize;

  /// Load from an explicit path, or resolve via [TWOKEY_CORE_LIB] / defaults.
  factory TwoKeyCoreFfi.open([String? libraryPath]) {
    final path = libraryPath ??
        Platform.environment['TWOKEY_CORE_LIB'] ??
        _defaultLibraryPath();
    return TwoKeyCoreFfi._(DynamicLibrary.open(path));
  }

  static String _defaultLibraryPath() {
    // From packages/dart → ../../target/{debug|release}/
    final root = Directory.current.path.contains('${Platform.pathSeparator}packages${Platform.pathSeparator}dart')
        ? Directory('../..').absolute.path
        : Directory.current.path;
    final name = Platform.isWindows
        ? 'two_key_core.dll'
        : Platform.isMacOS
            ? 'libtwo_key_core.dylib'
            : 'libtwo_key_core.so';
    final debug = File('$root${Platform.pathSeparator}target${Platform.pathSeparator}debug${Platform.pathSeparator}$name');
    if (debug.existsSync()) return debug.path;
    final release = File(
      '$root${Platform.pathSeparator}target${Platform.pathSeparator}release${Platform.pathSeparator}$name',
    );
    if (release.existsSync()) return release.path;
    throw TwoKeyException(
      TwoKeyErrorCode.config,
      'two_key_core native library not found. Build with '
      '`cargo build -p two-key-core` or set TWOKEY_CORE_LIB.',
      detail: debug.path,
    );
  }

  String normalizeApiBaseUrl(String input) {
    final inPtr = input.toNativeUtf8();
    final outPtr = _normalize(inPtr);
    calloc.free(inPtr);
    if (outPtr == nullptr) {
      throw TwoKeyException(TwoKeyErrorCode.config, 'normalize returned null');
    }
    final s = outPtr.toDartString();
    _free(outPtr);
    return s;
  }

  /// Calls Rust verify; returns parsed [LicensePayload] or throws [TwoKeyException].
  LicensePayload verifyLicenseJwt(String jwt, String publicKeyPem) {
    final pemPtr = publicKeyPem.toNativeUtf8();
    final jwtPtr = jwt.toNativeUtf8();
    final outPtr = _verify(pemPtr, jwtPtr);
    calloc.free(pemPtr);
    calloc.free(jwtPtr);
    if (outPtr == nullptr) {
      throw TwoKeyException(TwoKeyErrorCode.unknown, 'verify returned null');
    }
    final jsonStr = outPtr.toDartString();
    _free(outPtr);
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    if (map['ok'] == true) {
      // Full claims are not returned by the compact FFI summary — re-verify
      // is done in Rust; for payload fields hosts should use pureDart or
      // extend FFI. For dual-path smoke we decode a synthetic minimal payload
      // when only summary is present, OR we change FFI to return full claims.
      // Prefer: return full claims JSON from Rust.
      if (map.containsKey('claims')) {
        return LicensePayload.fromClaims(map['claims'] as Map<String, dynamic>);
      }
      // Fallback: treat success summary as insufficient for full payload —
      // call extended verify that returns claims.
      throw TwoKeyException(
        TwoKeyErrorCode.invalidResponse,
        'Rust verify succeeded but claims were not returned. '
        'Update two_key_verify_license_json to include claims.',
      );
    }
    final code = _codeFromWire(map['code'] as String? ?? 'unknown');
    throw TwoKeyException(
      code,
      map['message'] as String? ?? 'Verification failed',
    );
  }
}

TwoKeyErrorCode _codeFromWire(String wire) {
  return switch (wire) {
    'config' => TwoKeyErrorCode.config,
    'network' => TwoKeyErrorCode.network,
    'unauthorized' => TwoKeyErrorCode.unauthorized,
    'offline' => TwoKeyErrorCode.offline,
    'license_invalid' => TwoKeyErrorCode.licenseInvalid,
    'license_expired' => TwoKeyErrorCode.licenseExpired,
    'license_malformed' => TwoKeyErrorCode.licenseMalformed,
    'not_modified' => TwoKeyErrorCode.notModified,
    'invalid_response' => TwoKeyErrorCode.invalidResponse,
    _ => TwoKeyErrorCode.unknown,
  };
}
