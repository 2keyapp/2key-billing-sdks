import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:two_key_dart_sdk/two_key_dart_sdk.dart';

void main() {
  final fixtureFile = File('../../conformance/fixtures/license_payload_v1.json');

  test('normalizeApiBaseUrl strips /api/v1', () {
    expect(
      normalizeApiBaseUrl('https://billing.example.com/api/v1/'),
      'https://billing.example.com',
    );
  });

  test('fixture claims parse', () {
    final raw = jsonDecode(fixtureFile.readAsStringSync()) as Map<String, dynamic>;
    final claims = raw['claims'] as Map<String, dynamic>;
    final payload = parseLicenseClaims(claims);
    expect(payload.payloadVersion, 1);
    expect(payload.payingParty.id, 'pp_test_1');
    expect(payload.subscriptions.length, 2);
    expect(
      payload.subscriptions.any((s) => s.addonCode == 'ai_assistant'),
      isTrue,
    );
  });

  test('config requires storagePrefix', () {
    expect(
      () => const TwoKeySdkConfig(
        apiBaseUrl: 'https://billing.example.com',
        publicKeyPem: 'pem',
        storagePrefix: '  ',
      ).validated(),
      throwsA(isA<TwoKeyException>()),
    );
  });

  test('session roundtrip', () async {
    final mgr = SessionManager(
      config: const TwoKeySdkConfig(
        apiBaseUrl: 'https://billing.example.com',
        publicKeyPem: 'pem',
        storagePrefix: 'billing_test',
      ),
    );
    final session = AccountSession(accountKey: 'u1', accessToken: 'tok');
    await mgr.save(session);
    final loaded = await mgr.load('u1');
    expect(loaded?.accessToken, 'tok');
    await mgr.clear('u1');
    expect(await mgr.load('u1'), isNull);
  });

  test('portal urls', () {
    const cfg = TwoKeySdkConfig(
      apiBaseUrl: 'https://billing.example.com',
      publicKeyPem: 'pem',
      storagePrefix: 'app',
    );
    expect(shopUrl(cfg), 'https://billing.example.com/shop');
    expect(
      portalPathUrl(cfg, '/subscriptions'),
      'https://billing.example.com/subscriptions',
    );
  });

  test('rust backend flag not wired', () {
    TwoKeyRuntime.licenseBackend = LicenseBackend.rustCore;
    expect(TwoKeyRuntime.ensureBackendAvailable, throwsUnsupportedError);
    TwoKeyRuntime.licenseBackend = LicenseBackend.pureDart;
  });
}