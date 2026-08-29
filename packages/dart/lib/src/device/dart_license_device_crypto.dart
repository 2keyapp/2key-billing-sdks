import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'jwk_thumbprint.dart';
import 'license_device_keystore.dart';

/// Pure-Dart Ed25519 license-device identity (no native `two_key_core`).
Future<LicenseDeviceIdentity> generateDartLicenseDeviceIdentity() async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  final publicKey = await keyPair.extractPublicKey();
  final privateSeed = await keyPair.extractPrivateKeyBytes();

  final x = _b64Url(Uint8List.fromList(publicKey.bytes));
  final d = _b64Url(Uint8List.fromList(privateSeed));
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
