import 'dart:async';

import 'support/test_billing_crypto.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestBillingCrypto.install();
  await testMain();
}
