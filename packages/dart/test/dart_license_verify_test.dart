import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:two_key_dart_sdk/src/keys/default_public_key.dart';
import 'package:two_key_dart_sdk/two_key_dart_sdk.dart';

// Matches lib/src/keys/default_public_key.dart (ES256)
const _ecPrivKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgK/simzQCmAKvxHnO
2MWKGeTUNj2JL+HkZ8AGJ/oqwHKhRANCAAR4RUKisdiV4QRd6cJ/Y1RArTyevrrH
DcI/h/+lbVcG6QaSXALyCF6lcToJ8+hbIYYbxzle8zsSlDJmrlVpZ5qd
-----END PRIVATE KEY-----''';

String _token({Duration? expiresIn}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final exp = now + (expiresIn ?? const Duration(hours: 1)).inSeconds;
  final validUntil = now + const Duration(days: 30).inSeconds;
  return JWT(
    {
      'payload_version': 1,
      'iss': 'https://billing.example.com',
      'aud': 'billing',
      'iat': now,
      'exp': exp,
      'paying_party': {
        'id': 'party_456',
        'sso_id': 'sso_abc',
        'billing_email': 'billing@example.com',
        'organization_name': 'Acme Inc',
      },
      'subscriptions': [
        {
          'subscription_id': 'sub_canon_1',
          'plan_id': 'plan_premium',
          'product_id': 'prod_1',
          'plan_name': 'Premium',
          'product_name': 'Product One',
          'subscription_status': 'active',
          'valid_until': validUntil,
        },
      ],
    },
  ).sign(ECPrivateKey(_ecPrivKeyPem), algorithm: JWTAlgorithm.ES256);
}

void main() {
  setUp(() {
    BillingSdk.resetForTesting();
    BillingSdk.configure(
      billingApiBaseUrl: 'https://billing.example.com',
      publicKeyPem: defaultPublicKeyPem,
    );
  });

  tearDown(BillingSdk.resetForTesting);

  test('Dart path verifies a valid ES256 license without two_key_core', () {
    final result = BillingSdk.verifyAndDecode(_token());
    expect(result, isA<VerifySuccess>());
    expect((result as VerifySuccess).payload.payingParty.id, 'party_456');
    expect(BillingSdk.getPayload()?.payingParty.id, 'party_456');
  });

  test('Dart path rejects a malformed token', () {
    final result = BillingSdk.verifyAndDecode('not-a-jwt');
    expect(result, isA<VerifyFailure>());
    expect(
      (result as VerifyFailure).error.reason,
      BillingTokenErrorReason.malformed,
    );
  });

  test('Dart path rejects a token signed with another key', () {
    BillingSdk.resetForTesting();
    BillingSdk.configure(
      billingApiBaseUrl: 'https://billing.example.com',
      publicKeyPem: '''
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE3mY6OkUFDL9vYyYa+Ipb2cqCZVP7
GahkXZM4YU68XGhQmfCLONC58SfzB9gINYdQRtxcg0LHVfTUcdp/Wqt9rw==
-----END PUBLIC KEY-----
''',
    );
    final result = BillingSdk.verifyAndDecode(_token());
    expect(result, isA<VerifyFailure>());
    expect(
      (result as VerifyFailure).error.reason,
      BillingTokenErrorReason.invalidSignature,
    );
  });
}
