import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../models/billing_token_error.dart';
import '../models/billing_token_payload.dart';

/// ES256 license verify in Dart (no `two_key_core`).
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

  final JWT decoded;
  try {
    decoded = JWT.verify(
      trimmed,
      ECPublicKey(publicKeyPem),
      checkHeaderType: false,
    );
  } on JWTExpiredException {
    return const VerifyFailure(
      BillingTokenError(
        message:
            'This token has expired. Please sync or get a new token from the billing portal.',
        reason: BillingTokenErrorReason.expired,
      ),
    );
  } on JWTParseException catch (e) {
    return VerifyFailure(
      BillingTokenError(
        message: e.message.isNotEmpty
            ? e.message
            : 'Invalid format. Please paste the full token from the billing portal.',
        reason: BillingTokenErrorReason.malformed,
      ),
    );
  } on JWTInvalidException catch (e) {
    final lower = e.message.toLowerCase();
    if (lower.contains('signature')) {
      return const VerifyFailure(
        BillingTokenError(
          message: 'Invalid token. It may have been copied incorrectly.',
          reason: BillingTokenErrorReason.invalidSignature,
        ),
      );
    }
    return VerifyFailure(
      BillingTokenError(
        message:
            'Invalid format. Please paste the full token from the billing portal.',
        reason: BillingTokenErrorReason.malformed,
      ),
    );
  } on JWTException catch (e) {
    final lower = e.message.toLowerCase();
    if (lower.contains('expir')) {
      return VerifyFailure(
        BillingTokenError(
          message:
              'This token has expired. Please sync or get a new token from the billing portal.',
          reason: BillingTokenErrorReason.expired,
        ),
      );
    }
    if (lower.contains('pem') ||
        lower.contains('public key') ||
        lower.contains('ec key') ||
        lower.contains('algorithm')) {
      return VerifyFailure(
        BillingTokenError(
          message:
              'Offline verification failed: invalid billing public key format. '
              'Use an ES256 public key for JWT verification.',
          reason: BillingTokenErrorReason.invalidSignature,
        ),
      );
    }
    return const VerifyFailure(
      BillingTokenError(
        message: 'Invalid token. It may have been copied incorrectly.',
        reason: BillingTokenErrorReason.invalidSignature,
      ),
    );
  } catch (e) {
    return VerifyFailure(
      BillingTokenError(
        message: 'Invalid token. It may have been copied incorrectly. ($e)',
        reason: BillingTokenErrorReason.invalidSignature,
      ),
    );
  }

  final raw = decoded.payload;
  if (raw is! Map) {
    return const VerifyFailure(
      BillingTokenError(
        message: 'License verified but claims missing',
        reason: BillingTokenErrorReason.missingClaims,
      ),
    );
  }

  try {
    final payload = BillingTokenPayload.fromJson(Map<String, dynamic>.from(raw));
    if (payload.isExpired) {
      return const VerifyFailure(
        BillingTokenError(
          message:
              'This token has expired. Please sync or get a new token from the billing portal.',
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
