import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:two_key_dart_sdk/src/crypto/device_crypto.dart';

void main() {
  test('generateKeyAndCsr', () async {
    if (!deviceCryptoTestsEnabled()) {
      return;
    }

    final crypto = DeviceCrypto.open();
    final generated = await crypto.generateKeyAndCsr('camera.acme.example');
    expect(generated.ski, isNotEmpty);
    expect(generated.csrPem, contains('CERTIFICATE REQUEST'));
    expect(generated.privateJwk['d'], isNotNull);
  }, skip: Platform.environment.containsKey('CI') &&
      !deviceCryptoTestsEnabled()
          ? 'TWOKEY_CORE_LIB unset'
          : false);
}
