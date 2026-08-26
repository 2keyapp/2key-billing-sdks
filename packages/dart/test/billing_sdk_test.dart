import 'dart:io';

import 'package:two_key_dart_sdk/billing_dart_sdk.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_test/flutter_test.dart';

// Test key pair matching lib/src/keys/default_public_key.dart (ES256)
const _ecPrivKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgK/simzQCmAKvxHnO
2MWKGeTUNj2JL+HkZ8AGJ/oqwHKhRANCAAR4RUKisdiV4QRd6cJ/Y1RArTyevrrH
DcI/h/+lbVcG6QaSXALyCF6lcToJ8+hbIYYbxzle8zsSlDJmrlVpZ5qd
-----END PRIVATE KEY-----''';

String? _findCoreLib() {
  final candidates = <File>[
    File('../../bin/two_key_core.dll'),
    File('../../bin/libtwo_key_core.dylib'),
    File('../../bin/libtwo_key_core.so'),
  ];
  final dev = Platform.environment['TWOKEY_CORE_DEV_DIR'];
  if (dev != null && dev.isNotEmpty) {
    candidates.addAll([
      File('$dev/target/release/two_key_core.dll'),
      File('$dev/target/debug/two_key_core.dll'),
      File('$dev/target/release/libtwo_key_core.so'),
      File('$dev/target/debug/libtwo_key_core.so'),
      File('$dev/target/release/libtwo_key_core.dylib'),
    ]);
  }
  for (final f in candidates) {
    if (f.existsSync()) return f.absolute.path;
  }
  return null;
}

/// Flat payload: payload_version, iss, aud, iat, exp, paying_party, subscriptions[].
String _createCanonicalBillingToken({Duration? expiresIn}) {
  final exp = expiresIn != null
      ? DateTime.now().add(expiresIn).millisecondsSinceEpoch ~/ 1000
      : DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
  final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final validUntil =
      DateTime.now().toUtc().add(const Duration(days: 30)).millisecondsSinceEpoch ~/
          1000;
  final jwt = JWT(
    {
      'payload_version': 1,
      'iss': 'https://billing.example.com',
      'aud': 'billing',
      'iat': iat,
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
          'assigned_user_party_id': null,
        },
      ],
    },
  );
  return jwt.sign(ECPrivateKey(_ecPrivKeyPem), algorithm: JWTAlgorithm.ES256);
}

void main() {
  final coreLib = _findCoreLib();

  group('BillingSdk', () {
    setUpAll(() {
      if (coreLib == null) {
        // ignore: avoid_print
        print(
          'skip BillingSdk rust tests: set TWOKEY_CORE_DEV_DIR or fetch binaries',
        );
      }
    });

    setUp(() {
      if (coreLib == null) return;
      BillingSdk.configureForTesting(
        billingApiBaseUrl: 'https://billing.example.com',
        coreLibraryPath: coreLib,
      );
    });

    tearDown(() {
      BillingSdk.resetForTesting();
    });

    group('init', () {
      test('init(null) leaves payload null', () {
        if (coreLib == null) return;
        BillingSdk.init(null);
        expect(BillingSdk.getPayload(), isNull);
      });

      test('init(empty string) leaves payload null', () {
        if (coreLib == null) return;
        BillingSdk.init('');
        expect(BillingSdk.getPayload(), isNull);
      });

      test('init(invalid token) leaves payload null', () {
        if (coreLib == null) return;
        BillingSdk.init('not.a.jwt');
        expect(BillingSdk.getPayload(), isNull);
      });

      test('init(valid token) stores payload', () {
        if (coreLib == null) return;
        final token = _createCanonicalBillingToken();
        BillingSdk.init(token);
        final payload = BillingSdk.getPayload();
        expect(payload, isNotNull);
        expect(payload!.payingParty.id, 'party_456');
        expect(payload.payingParty.ssoId, 'sso_abc');
        expect(payload.payingParty.billingEmail, 'billing@example.com');
        expect(payload.subscriptionIds, ['sub_canon_1']);
        expect(payload.email, 'billing@example.com');
        expect(payload.hasSubscription('sub_canon_1'), isTrue);
        expect(payload.hasSubscription('sub_99'), isFalse);
        expect(payload.hasPlan('plan_premium'), isTrue);
        expect(payload.hasProduct('prod_1'), isTrue);
      });
    });

    group('verifyAndDecode', () {
      test('empty string returns VerifyFailure malformed', () {
        if (coreLib == null) return;
        final result = BillingSdk.verifyAndDecode('');
        expect(result, isA<VerifyFailure>());
        expect(
          (result as VerifyFailure).error.reason,
          BillingTokenErrorReason.malformed,
        );
      });

      test('invalid token returns VerifyFailure', () {
        if (coreLib == null) return;
        final result = BillingSdk.verifyAndDecode('invalid');
        expect(result, isA<VerifyFailure>());
      });

      test('valid token returns VerifySuccess and updates getPayload', () {
        if (coreLib == null) return;
        final token = _createCanonicalBillingToken();
        final result = BillingSdk.verifyAndDecode(token);
        expect(result, isA<VerifySuccess>());
        final payload = (result as VerifySuccess).payload;
        expect(payload.payingParty.id, 'party_456');
        expect(BillingSdk.getPayload()?.payingParty.id, 'party_456');
      });
    });

    group('syncFromServer', () {
      test('without billingApiBaseUrl throws on sync', () async {
        if (coreLib == null) return;
        BillingSdk.resetForTesting();
        RustBillingCore.open(coreLib);
        expectLater(
          BillingSdk.syncFromServer(authorizationToken: 'Bearer x'),
          throwsStateError,
        );
      });

      test('with empty authorizationToken returns SyncFailure', () async {
        if (coreLib == null) return;
        final result = await BillingSdk.syncFromServer(authorizationToken: '');
        expect(result, isA<SyncFailure>());
        expect((result as SyncFailure).message, contains('token'));
      });

      test('verify without public key throws', () {
        if (coreLib == null) return;
        BillingSdk.resetForTesting();
        BillingSdk.configure(
          billingApiBaseUrl: 'https://billing.example.com',
          coreLibraryPath: coreLib,
        );
        expect(
          () => BillingSdk.verifyAndDecode('a.b.c'),
          throwsStateError,
        );
      });
    });

    group('normalizeBillingApiBaseUrl', () {
      test('strips trailing slashes', () {
        expect(
          normalizeBillingApiBaseUrl('https://billing.example.com///'),
          'https://billing.example.com',
        );
      });

      test('strips /api/billing suffix', () {
        expect(
          normalizeBillingApiBaseUrl('https://billing.example.com/api/billing'),
          'https://billing.example.com',
        );
        expect(
          normalizeBillingApiBaseUrl(
            'https://billing.example.com/api/billing/',
          ),
          'https://billing.example.com',
        );
      });

      test('leaves origin unchanged when no suffix', () {
        expect(
          normalizeBillingApiBaseUrl('https://billing.example.com'),
          'https://billing.example.com',
        );
      });
    });
  });
}
