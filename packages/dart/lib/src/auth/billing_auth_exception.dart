/// Thrown when billing auth or OAuth token exchange fails.
class BillingAuthException implements Exception {
  const BillingAuthException(
    this.message, {
    this.statusCode,
    this.code,
    this.responseBody,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final String? responseBody;

  @override
  String toString() => message;
}

/// Session is authenticated but has no bound organization (`ORG_SLUG_REQUIRED`).
class BillingOrgSlugRequiredException extends BillingAuthException {
  const BillingOrgSlugRequiredException([
    String message = 'Bind an organization slug before minting a billing token',
  ]) : super(message, statusCode: 403, code: 'ORG_SLUG_REQUIRED');
}
