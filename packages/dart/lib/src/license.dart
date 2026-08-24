import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import 'errors.dart';

dynamic _getKey(Map<String, dynamic> m, String snake, String camel) =>
    m[snake] ?? m[camel];

int? _parseInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return null;
}

class PayingParty {
  const PayingParty({
    required this.id,
    required this.identityProvider,
    required this.identitySubject,
    required this.billingEmail,
    this.organizationName,
  });

  final String id;
  final String identityProvider;
  final String identitySubject;
  final String billingEmail;
  final String? organizationName;

  factory PayingParty.fromJson(Map<String, dynamic> json) {
    final id = _getKey(json, 'id', 'id');
    final billingEmail = _getKey(json, 'billing_email', 'billingEmail');
    if (id is! String || id.isEmpty) {
      throw TwoKeyException(TwoKeyErrorCode.licenseMalformed, 'paying_party.id required');
    }
    if (billingEmail is! String) {
      throw TwoKeyException(
        TwoKeyErrorCode.licenseMalformed,
        'paying_party.billing_email required',
      );
    }
    var provider = _getKey(json, 'identity_provider', 'identityProvider');
    var subject = _getKey(json, 'identity_subject', 'identitySubject');
    final sso = _getKey(json, 'sso_id', 'ssoId');
    if ((provider is! String || provider.isEmpty || subject is! String || subject.isEmpty) &&
        sso is String &&
        sso.isNotEmpty) {
      provider = provider is String && provider.isNotEmpty ? provider : 'legacy';
      subject = subject is String && subject.isNotEmpty ? subject : sso;
    }
    if (provider is! String || provider.isEmpty || subject is! String || subject.isEmpty) {
      throw TwoKeyException(
        TwoKeyErrorCode.licenseMalformed,
        'paying_party: identity_provider and identity_subject required (or legacy sso_id)',
      );
    }
    final org = _getKey(json, 'organization_name', 'organizationName');
    return PayingParty(
      id: id,
      identityProvider: provider,
      identitySubject: subject,
      billingEmail: billingEmail,
      organizationName: org is String ? org : null,
    );
  }
}

class BillingSubscription {
  const BillingSubscription({
    required this.subscriptionId,
    required this.planId,
    required this.productId,
    required this.planName,
    required this.productName,
    required this.subscriptionStatus,
    required this.validUntilUnix,
    this.validFromUnix,
    this.billingInterval,
    this.addonCode,
  });

  final String subscriptionId;
  final String planId;
  final String productId;
  final String planName;
  final String productName;
  final String subscriptionStatus;
  final int validUntilUnix;
  final int? validFromUnix;
  final String? billingInterval;
  final String? addonCode;

  bool get isActive {
    final s = subscriptionStatus.toLowerCase();
    return s == 'active' || s == 'trialing';
  }

  factory BillingSubscription.fromJson(Map<String, dynamic> json) {
    String req(String snake, String camel) {
      final v = _getKey(json, snake, camel);
      if (v is! String) {
        throw TwoKeyException(
          TwoKeyErrorCode.licenseMalformed,
          'subscriptions[].$snake required',
        );
      }
      return v;
    }

    final validUntil = _parseInt(_getKey(json, 'valid_until', 'validUntil'));
    if (validUntil == null) {
      throw TwoKeyException(
        TwoKeyErrorCode.licenseMalformed,
        'subscriptions[].valid_until required (Unix timestamp)',
      );
    }
    final addon = _getKey(json, 'addon_code', 'addonCode');
    final interval = _getKey(json, 'billing_interval', 'billingInterval');
    return BillingSubscription(
      subscriptionId: req('subscription_id', 'subscriptionId'),
      planId: req('plan_id', 'planId'),
      productId: req('product_id', 'productId'),
      planName: req('plan_name', 'planName'),
      productName: req('product_name', 'productName'),
      subscriptionStatus: req('subscription_status', 'subscriptionStatus'),
      validUntilUnix: validUntil,
      validFromUnix: _parseInt(_getKey(json, 'valid_from', 'validFrom')),
      billingInterval: interval is String && interval.isNotEmpty ? interval : null,
      addonCode: addon is String && addon.isNotEmpty ? addon : null,
    );
  }
}

class LicensePayload {
  const LicensePayload({
    required this.payloadVersion,
    required this.expiresAtUnix,
    required this.payingParty,
    required this.subscriptions,
    this.issuedAtUnix,
    this.issuer,
    this.audience,
  });

  final int payloadVersion;
  final int expiresAtUnix;
  final int? issuedAtUnix;
  final String? issuer;
  final String? audience;
  final PayingParty payingParty;
  final List<BillingSubscription> subscriptions;

  factory LicensePayload.fromClaims(Map<String, dynamic> json) {
    final version = _parseInt(_getKey(json, 'payload_version', 'payloadVersion'));
    if (version == null) {
      throw TwoKeyException(
        TwoKeyErrorCode.licenseMalformed,
        'payload_version (number) required',
      );
    }
    final payingRaw = _getKey(json, 'paying_party', 'payingParty');
    if (payingRaw is! Map<String, dynamic>) {
      throw TwoKeyException(
        TwoKeyErrorCode.licenseMalformed,
        'paying_party object required',
      );
    }
    final subsRaw = json['subscriptions'];
    if (subsRaw is! List) {
      throw TwoKeyException(
        TwoKeyErrorCode.licenseMalformed,
        'subscriptions array required',
      );
    }
    final subs = <BillingSubscription>[];
    for (var i = 0; i < subsRaw.length; i++) {
      final item = subsRaw[i];
      if (item is! Map<String, dynamic>) {
        throw TwoKeyException(
          TwoKeyErrorCode.licenseMalformed,
          'subscriptions[$i] must be an object',
        );
      }
      subs.add(BillingSubscription.fromJson(item));
    }
    return LicensePayload(
      payloadVersion: version,
      expiresAtUnix: _parseInt(json['exp']) ?? 4102444800,
      issuedAtUnix: _parseInt(json['iat']),
      issuer: json['iss'] is String ? json['iss'] as String : null,
      audience: json['aud'] is String ? json['aud'] as String : null,
      payingParty: PayingParty.fromJson(payingRaw),
      subscriptions: subs,
    );
  }
}

/// Verify ES256 license JWT (matches Rust / TS claim rules).
LicensePayload verifyLicenseJwt(String token, String publicKeyPem) {
  final trimmed = token.trim();
  if (trimmed.isEmpty) {
    throw TwoKeyException(
      TwoKeyErrorCode.licenseMalformed,
      'Invalid format. Please paste the full token from the billing portal.',
    );
  }
  try {
    final jwt = JWT.tryVerify(
      trimmed,
      ECPublicKey(publicKeyPem),
      checkExpiresIn: true,
      checkNotBefore: false,
    );
    if (jwt == null) {
      throw TwoKeyException(
        TwoKeyErrorCode.licenseInvalid,
        'Invalid token. It may have been copied incorrectly.',
      );
    }
    final payloadMap = jwt.payload;
    if (payloadMap is! Map<String, dynamic>) {
      throw TwoKeyException(
        TwoKeyErrorCode.licenseMalformed,
        'Token is missing required data.',
      );
    }
    return LicensePayload.fromClaims(payloadMap);
  } on TwoKeyException {
    rethrow;
  } on JWTExpiredException {
    throw TwoKeyException(
      TwoKeyErrorCode.licenseExpired,
      'This token has expired. Please sync or get a new token from the billing portal.',
    );
  } on JWTException {
    throw TwoKeyException(
      TwoKeyErrorCode.licenseInvalid,
      'Invalid token. It may have been copied incorrectly.',
    );
  } catch (_) {
    throw TwoKeyException(
      TwoKeyErrorCode.licenseMalformed,
      'Invalid format. Please paste the full token from the billing portal.',
    );
  }
}

/// Parse unsigned claims (conformance fixtures).
LicensePayload parseLicenseClaims(Map<String, dynamic> claims) =>
    LicensePayload.fromClaims(claims);
