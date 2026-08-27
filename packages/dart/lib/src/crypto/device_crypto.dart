import 'dart:convert';
import 'dart:io';

import '../frb/frb_wire.dart';

/// Device x.509 / mTLS / PoP crypto via `two_key_crypto_*` C ABI.
class DeviceCrypto {
  DeviceCrypto._(this._wire);

  final FrbWire _wire;

  /// Open from [FrbWire] (requires v0.1.2+ core with crypto symbols).
  factory DeviceCrypto.open([String? libraryPath]) {
    return DeviceCrypto._(FrbWire.open(libraryPath));
  }

  /// True when native core is available (crypto requires v0.1.2+ at runtime).
  static bool get isAvailable => FrbWire.isAvailable;

  /// Generate Ed25519 keypair + PKCS#10 CSR for [host].
  Future<GeneratedKeyAndCsr> generateKeyAndCsr(String host, {String? commonName}) async {
    final result = _wire.cryptoGenerateKeyAndCsr(
      jsonEncode({
        'host': host,
        if (commonName != null) 'commonName': commonName,
      }),
    );
    _assertOk(result);
    final data = result['data'] as Map<String, dynamic>;
    return GeneratedKeyAndCsr(
      ski: data['ski'] as String? ?? '',
      publicJwk: Map<String, dynamic>.from(data['publicJwk'] as Map? ?? {}),
      privateJwk: Map<String, dynamic>.from(data['privateJwk'] as Map? ?? {}),
      csrPem: data['csrPem'] as String? ?? '',
    );
  }

  /// Sign a device CSR with a CA private JWK → leaf + chain PEM.
  Future<SignedClientCert> signClientCertFromCsr({
    required String csrPem,
    required String caCertPem,
    required Map<String, dynamic> caPrivateJwk,
    required String caCommonName,
    required String ski,
    String? host,
    int? notAfterDays,
  }) async {
    final result = _wire.cryptoSignClientCertFromCsr(
      jsonEncode({
        'csrPem': csrPem,
        'caCertPem': caCertPem,
        'caPrivateJwk': caPrivateJwk,
        'caCommonName': caCommonName,
        'ski': ski,
        if (host != null) 'host': host,
        if (notAfterDays != null) 'notAfterDays': notAfterDays,
      }),
    );
    _assertOk(result);
    final data = result['data'] as Map<String, dynamic>;
    return SignedClientCert(
      leafPem: data['leafPem'] as String? ?? '',
      chainPem: data['chainPem'] as String? ?? '',
    );
  }

  /// Verify leaf cert Ed25519 signature against issuer PEM.
  Future<bool> verifyCert({
    required String leafPem,
    required String issuerPem,
  }) async {
    final result = _wire.cryptoVerifyEd25519Cert(
      jsonEncode({'leafPem': leafPem, 'issuerPem': issuerPem}),
    );
    _assertOk(result);
    final data = result['data'] as Map<String, dynamic>;
    return data['valid'] as bool? ?? false;
  }

  /// Build mTLS client PEM material from persisted identity JSON.
  Future<MtlsClientMaterial> materializeMtls({
    required Map<String, dynamic> identityJson,
  }) async {
    final result = _wire.cryptoMaterializeMtlsClient(jsonEncode(identityJson));
    _assertOk(result);
    final data = result['data'] as Map<String, dynamic>;
    return MtlsClientMaterial(
      certPem: data['certPem'] as String? ?? '',
      keyPem: data['keyPem'] as String? ?? '',
      ski: data['ski'] as String? ?? '',
      chainPem: data['chainPem'] as String?,
    );
  }

  /// Sign JSON payload with Ed25519 private PEM (agent proof-of-possession).
  Future<String> signJsonB64Url({
    required String privatePem,
    required String payloadJson,
  }) async {
    final result = _wire.cryptoSignJsonB64Url(
      jsonEncode({'privatePem': privatePem, 'payloadJson': payloadJson}),
    );
    _assertOk(result);
    final data = result['data'] as Map<String, dynamic>;
    return data['signature'] as String? ?? '';
  }

  void _assertOk(Map<String, dynamic> result) {
    if (result['ok'] != true) {
      throw DeviceCryptoException(
        result['code'] as String? ?? 'crypto',
        result['message'] as String? ?? 'crypto operation failed',
      );
    }
  }
}

class DeviceCryptoException implements Exception {
  DeviceCryptoException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'DeviceCryptoException($code): $message';
}

class GeneratedKeyAndCsr {
  const GeneratedKeyAndCsr({
    required this.ski,
    required this.publicJwk,
    required this.privateJwk,
    required this.csrPem,
  });

  final String ski;
  final Map<String, dynamic> publicJwk;
  final Map<String, dynamic> privateJwk;
  final String csrPem;
}

class SignedClientCert {
  const SignedClientCert({required this.leafPem, required this.chainPem});

  final String leafPem;
  final String chainPem;
}

class MtlsClientMaterial {
  const MtlsClientMaterial({
    required this.certPem,
    required this.keyPem,
    required this.ski,
    this.chainPem,
  });

  final String certPem;
  final String keyPem;
  final String ski;
  final String? chainPem;
}

/// Skip crypto integration tests when core library is unavailable.
bool deviceCryptoTestsEnabled() {
  if (Platform.environment['TWOKEY_CORE_LIB']?.isNotEmpty == true) return true;
  if (Platform.environment['TWOKEY_CORE_DEV_DIR']?.isNotEmpty == true) {
    return true;
  }
  return DeviceCrypto.isAvailable;
}
