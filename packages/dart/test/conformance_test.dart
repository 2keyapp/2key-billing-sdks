import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:two_key_dart_sdk/two_key_dart_sdk.dart';

void main() {
  final fixtureFile = File('../../conformance/fixtures/license_payload_v1.json');

  test('normalizeBillingApiBaseUrl strips /api/v1', () {
    expect(
      normalizeBillingApiBaseUrl('https://billing.example.com/api/v1/'),
      'https://billing.example.com',
    );
  });

  test('fixture claims parse', () {
    final raw =
        jsonDecode(fixtureFile.readAsStringSync()) as Map<String, dynamic>;
    final claims = raw['claims'] as Map<String, dynamic>;
    final payload = BillingTokenPayload.fromJson(claims);
    expect(payload.payloadVersion, 1);
    expect(payload.payingParty.id, 'pp_test_1');
    expect(payload.subscriptions.length, 2);
    expect(
      payload.subscriptions.any((s) => s.addonCode == 'ai_assistant'),
      isTrue,
    );
  });

  test('config requires non-empty storagePrefix for session stores', () {
    const cfg = BillingSdkConfig(
      apiBaseUrl: 'https://billing.example.com',
      deepLinkScheme: 'app',
      storagePrefix: '  ',
      publicKeyPem: 'pem',
    );
    expect(cfg.storagePrefix.trim().isEmpty, isTrue);
  });

  test('session roundtrip', () async {
    final store = InMemoryBillingSessionStore();
    final session = BillingAccountSession(
      authTokens: const BillingAuthTokens(accessToken: 'tok'),
      userProfile: const AuthUserProfile(subject: 'u1'),
    );
    await store.writeAccountSession('u1', session);
    final loaded = await store.readAccountSession('u1');
    expect(loaded?.accessToken, 'tok');
    await store.deleteAccountSession('u1');
    expect(await store.readAccountSession('u1'), isNull);
  });

  test('portal urls', () {
    const portal = BillingPortalUrls(
      portalBaseUrl: 'https://billing.example.com',
    );
    expect(portal.marketplace().toString(), 'https://billing.example.com/shop');
    expect(
      portal.home().replace(path: '/subscriptions').toString(),
      'https://billing.example.com/subscriptions',
    );
  });

  test('LicenseBackend has pureDart and rustCore', () {
    expect(LicenseBackend.pureDart, isNot(LicenseBackend.rustCore));
    expect(RustBillingCore.preferredBackend, LicenseBackend.rustCore);
  });
}
