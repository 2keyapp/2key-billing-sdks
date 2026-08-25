import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Which license implementation to prefer when dual-path is enabled.
enum LicenseBackend {
  /// Pure Dart (`dart_jsonwebtoken`) — default.
  pureDart,

  /// Prebuilt `two_key_core` cdylib from private `2key-core-sdk` Releases.
  rustCore,
}

/// Thrown when the native core library is missing or returns an error.
class TwoKeyFfiException implements Exception {
  TwoKeyFfiException(this.code, this.message, {this.detail});

  final String code;
  final String message;
  final String? detail;

  @override
  String toString() => 'TwoKeyFfiException($code): $message'
      '${detail != null ? ' ($detail)' : ''}';
}

/// Low-level bindings to `two_key_core` cdylib (C ABI).
///
/// Obtain binaries via `scripts/fetch-binaries.*` or
/// `TWOKEY_CORE_DEV_DIR` pointing at a local `2key-core-sdk` build.
class TwoKeyCoreFfi {
  TwoKeyCoreFfi._(this._lib)
      : _verify = _lib.lookupFunction<_VerifyNative, _VerifyDart>(
          'two_key_verify_license_json',
        ),
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
    throw TwoKeyFfiException(
      'config',
      'two_key_core native library not found. '
      'Run scripts/fetch-binaries or set TWOKEY_CORE_LIB / TWOKEY_CORE_DEV_DIR.',
      detail: candidates.join(' | '),
    );
  }

  String normalizeApiBaseUrl(String input) {
    final inPtr = input.toNativeUtf8();
    final outPtr = _normalize(inPtr);
    calloc.free(inPtr);
    if (outPtr == nullptr) {
      throw TwoKeyFfiException('config', 'normalize returned null');
    }
    final s = outPtr.toDartString();
    _free(outPtr);
    return s;
  }

  /// Calls Rust verify; returns parsed JSON map (`ok` / `claims` / error fields).
  Map<String, dynamic> verifyLicenseJwtJson(String jwt, String publicKeyPem) {
    final pemPtr = publicKeyPem.toNativeUtf8();
    final jwtPtr = jwt.toNativeUtf8();
    final outPtr = _verify(pemPtr, jwtPtr);
    calloc.free(pemPtr);
    calloc.free(jwtPtr);
    if (outPtr == nullptr) {
      throw TwoKeyFfiException('unknown', 'verify returned null');
    }
    final jsonStr = outPtr.toDartString();
    _free(outPtr);
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }
}

typedef _VerifyNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _VerifyDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);
typedef _NormalizeNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _NormalizeDart = Pointer<Utf8> Function(Pointer<Utf8>);
