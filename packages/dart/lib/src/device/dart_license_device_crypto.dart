import 'dart:convert';
import 'dart:typed_data';

import '../crypto/billing_crypto_provider.dart';
import 'jwk_thumbprint.dart';
import 'license_device_keystore.dart';

/// Ed25519 license-device identity from the installed [BillingCryptoProvider]
/// (no native `two_key_core`).
Future<LicenseDeviceIdentity> generateDartLicenseDeviceIdentity() async {
  final crypto = BillingCryptoProvider.current;
  final privateSeed = crypto.randomBytes(32);
  final publicKey = await crypto.ed25519PublicFromSeed(privateSeed);

  final x = _b64Url(publicKey);
  final d = _b64Url(privateSeed);
  final publicJwk = <String, dynamic>{
    'kty': 'OKP',
    'crv': 'Ed25519',
    'x': x,
  };
  final privateJwk = <String, dynamic>{
    ...publicJwk,
    'd': d,
  };
  final ski = jwkThumbprintSha256(publicJwk);
  return LicenseDeviceIdentity(
    publicJwk: publicJwk,
    ski: ski,
    privateJwk: privateJwk,
  );
}

String _b64Url(Uint8List bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
