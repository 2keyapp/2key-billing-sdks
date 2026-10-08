import 'dart:convert';
import 'dart:typed_data';

import '../crypto/billing_crypto_provider.dart';
import '../models/billing_token_error.dart';
import '../models/billing_token_payload.dart';

/// ES256 license verify through the installed [BillingCryptoProvider]
/// (no `two_key_core`).
///
/// Used when the native library is not loaded. Signature and claim parsing
/// match the JS `verifyLicenseJwt` / rust `verifyLicense` success path.
VerifyResult verifyLicenseJwtDart({
  required String jwt,
  required String publicKeyPem,
}) {
  final trimmed = jwt.trim();
  if (trimmed.isEmpty) {
    return const VerifyFailure(
      BillingTokenError(
        message:
            'Invalid format. Please paste the full token from the billing portal.',
        reason: BillingTokenErrorReason.malformed,
      ),
    );
  }

  final Map<String, dynamic> claims;
  try {
    claims = _verifyEs256(trimmed, publicKeyPem);
  } on _Malformed {
    return const VerifyFailure(
      BillingTokenError(
        message:
            'Invalid format. Please paste the full token from the billing portal.',
        reason: BillingTokenErrorReason.malformed,
      ),
    );
  } on _BadKey {
    return const VerifyFailure(
      BillingTokenError(
        message:
            'Offline verification failed: invalid billing public key format. '
            'Use an ES256 public key for JWT verification.',
        reason: BillingTokenErrorReason.invalidSignature,
      ),
    );
  } on _BadSignature {
    return const VerifyFailure(
      BillingTokenError(
        message: 'Invalid token. It may have been copied incorrectly.',
        reason: BillingTokenErrorReason.invalidSignature,
      ),
    );
  }

  try {
    final payload = BillingTokenPayload.fromJson(claims);
    if (payload.hasExpiredIncludedSubscription) {
      return const VerifyFailure(
        BillingTokenError(
          message:
              'A subscription on this license has expired. Get a new license from the billing portal.',
          reason: BillingTokenErrorReason.expired,
        ),
      );
    }
    return VerifySuccess(payload);
  } on FormatException catch (e) {
    return VerifyFailure(
      BillingTokenError(
        message: e.message,
        reason: BillingTokenErrorReason.missingClaims,
      ),
    );
  }
}

class _Malformed implements Exception {}

class _BadKey implements Exception {}

class _BadSignature implements Exception {}

/// Compact JWS, `alg: ES256`. Header type and `exp` are not checked here;
/// `nbf` is. Returns the claims.
Map<String, dynamic> _verifyEs256(String jwt, String publicKeyPem) {
  final parts = jwt.split('.');
  if (parts.length != 3) throw _Malformed();
  final Map<String, dynamic> header;
  final Object? payload;
  final Uint8List signature;
  try {
    header = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(_b64UrlDecode(parts[0]))) as Map,
    );
    payload = jsonDecode(utf8.decode(_b64UrlDecode(parts[1])));
    signature = _b64UrlDecode(parts[2]);
  } catch (_) {
    throw _Malformed();
  }
  if (header['alg'] != 'ES256') throw _BadSignature();

  final Uint8List spki;
  try {
    spki = _pemToDer(publicKeyPem);
  } catch (_) {
    throw _BadKey();
  }
  final bool ok;
  try {
    ok = BillingCryptoProvider.current.ecdsaP256Sha256Verify(
      spkiDer: spki,
      message: Uint8List.fromList(utf8.encode('${parts[0]}.${parts[1]}')),
      rawSignature: signature,
    );
  } on StateError {
    rethrow;
  } catch (_) {
    throw _BadKey();
  }
  if (!ok) throw _BadSignature();

  if (payload is! Map) throw _Malformed();
  final claims = Map<String, dynamic>.from(payload);
  final nbf = claims['nbf'];
  if (nbf is num &&
      nbf > DateTime.now().millisecondsSinceEpoch ~/ 1000) {
    throw _BadSignature();
  }
  return claims;
}

Uint8List _b64UrlDecode(String s) =>
    Uint8List.fromList(base64Url.decode(base64Url.normalize(s)));

Uint8List _pemToDer(String pem) {
  final body = pem
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('-----'))
      .join();
  if (body.isEmpty) throw const FormatException('empty PEM');
  return Uint8List.fromList(base64.decode(body));
}
