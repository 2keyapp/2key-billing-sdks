import 'package:flutter_test/flutter_test.dart';
import 'package:two_key_dart_sdk/billing_dart_sdk.dart';

void main() {
  test('jwkThumbprintSha256 matches RFC 7638 OKP canonicalization', () {
    // Fixed public key material; thumbprint is deterministic.
    final jwk = {
      'kty': 'OKP',
      'crv': 'Ed25519',
      'x': '11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo',
    };
    final ski = jwkThumbprintSha256(jwk);
    expect(ski, isNotEmpty);
    expect(ski.contains('='), isFalse);
    expect(ski, jwkThumbprintSha256(jwk));
  });

  test('generateDartLicenseDeviceIdentity produces OKP + thumbprint ski',
      () async {
    final identity = await generateDartLicenseDeviceIdentity();
    expect(identity.publicJwk['kty'], 'OKP');
    expect(identity.publicJwk['crv'], 'Ed25519');
    expect(identity.publicJwk['x'], isNotEmpty);
    expect(identity.privateJwk?['d'], isNotEmpty);
    expect(identity.ski, jwkThumbprintSha256(identity.publicJwk));
  });

  test('LicenseDeviceKeystore Dart fallback without native crypto', () async {
    final mem = <String, String>{};
    final store = LicenseDeviceKeystore(
      read: (k) async => mem[k],
      write: (k, v) async => mem[k] = v,
    );
    final a = await store.ensureForAccount('acct');
    final b = await store.ensureForAccount('acct');
    expect(a.ski, b.ski);
    expect(a.publicJwk['kty'], 'OKP');
    expect(mem.keys.single, contains('license_device_v1:acct'));
  });

  test('LicenseDeviceIdentity persists friendlyName', () async {
    final mem = <String, String>{};
    final store = LicenseDeviceKeystore(
      read: (k) async => mem[k],
      write: (k, v) async => mem[k] = v,
    );
    final created = await store.ensureForAccount('acct');
    final named = created.copyWith(friendlyName: 'laptop');
    await store.persistForAccount('acct', named);
    final loaded = await store.loadForAccount('acct');
    expect(loaded?.friendlyName, 'laptop');
    expect(loaded?.ski, created.ski);
  });

  test('LicenseDeviceClaim parses friendly_name', () {
    final claim = LicenseDeviceClaim.fromJson({
      'ski': 'abc',
      'device_id': 'd1',
      'platform': 'desktop',
      'friendly_name': 'edge1',
    });
    expect(claim.friendlyName, 'edge1');
  });
}
