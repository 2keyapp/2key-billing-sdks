import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:two_key_dart_sdk/src/frb/frb.dart';
import 'package:two_key_dart_sdk/src/keys/default_public_key.dart';
import 'package:two_key_dart_sdk/two_key_dart_sdk.dart';

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

void main() {
  tearDown(() {
    BillingSdk.resetForTesting();
    RustBillingCore.resetForTesting();
  });

  test('BillingMode offline blocks sync', () async {
    final session = BillingSession(
      store: InMemoryBillingSessionStore(),
      mode: BillingMode.offline,
    );
    final outcome = await session.syncOnlineForAccount(accountKey: 'u1');
    expect(outcome, isA<SessionSyncFailure>());
    expect(
      (outcome as SessionSyncFailure).message,
      contains('offline mode'),
    );
  });

  test('FrbWire normalize when cdylib present', () {
    final lib = _findCoreLib();
    if (lib == null) {
      // ignore: avoid_print
      print('skip: build/fetch two-key-core cdylib');
      return;
    }
    final wire = FrbWire.open(lib);
    expect(
      wire.normalizeApiBaseUrl('https://billing.example.com/api/v1/'),
      'https://billing.example.com',
    );
  });

  test('RustBillingCore verify rejects bad jwt when cdylib present', () {
    final lib = _findCoreLib();
    if (lib == null) {
      // ignore: avoid_print
      print('skip: build/fetch two-key-core cdylib');
      return;
    }
    final core = RustBillingCore.open(lib);
    final result = core.verifyLicense(
      publicKeyPem: defaultPublicKeyPem,
      jwt: 'not.a.jwt',
    );
    expect(result, isA<VerifyFailure>());
  });

  test('BillingSdk requires native core', () {
    final lib = _findCoreLib();
    if (lib == null) {
      expect(
        () => BillingSdk.configureForTesting(),
        throwsA(isA<StateError>()),
      );
      return;
    }
    BillingSdk.configureForTesting(
      billingApiBaseUrl: 'https://billing.example.com',
      coreLibraryPath: lib,
    );
    expect(RustBillingCore.tryOpen(lib), isNotNull);
  });

  test('syncLicense JSON rejects missing token via rust', () {
    final lib = _findCoreLib();
    if (lib == null) {
      // ignore: avoid_print
      print('skip: build/fetch two-key-core cdylib');
      return;
    }
    final core = RustBillingCore.open(lib);
    final out = core.syncLicense(
      apiBaseUrl: 'https://billing.example.com',
      publicKeyPem: defaultPublicKeyPem,
      session: {
        'account_key': 'u1',
        'access_token': null,
        'license_jwt': null,
        'license_etag': null,
        'paying_party_id_header': null,
      },
    );
    expect(out, isA<RustSyncFailure>());
  });
}
