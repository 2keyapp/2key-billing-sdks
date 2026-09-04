import 'package:flutter_test/flutter_test.dart';
import 'package:two_key_dart_sdk/billing_dart_sdk.dart';

void main() {
  test('callback nonce param is stable for host waiters', () {
    expect(BillingAuthRedirect.callbackNonceQueryParam, 'ba_nonce');
    expect(
      BillingAuthRedirect.callbackNonceMatches(
        expected: 'abc',
        actual: 'abc',
      ),
      isTrue,
    );
    expect(
      BillingAuthRedirect.callbackNonceMatches(
        expected: 'abc',
        actual: 'other',
      ),
      isFalse,
    );
    expect(
      BillingAuthRedirect.callbackNonceMatches(
        expected: 'abc',
        actual: null,
      ),
      isFalse,
    );
  });
}
