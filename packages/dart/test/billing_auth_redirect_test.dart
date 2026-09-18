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

  test('session cookie is ignored without echoed ba_nonce', () {
    const nonce = 'expected-nonce';
    expect(
      BillingAuthRedirect.sessionCookieIfNonceMatches(
        callback: Uri.parse('myapp://auth/callback?cookie=attacker-session'),
        expectedNonce: nonce,
      ),
      isNull,
    );
    expect(
      BillingAuthRedirect.sessionCookieIfNonceMatches(
        callback: Uri.parse(
          'myapp://auth/callback?cookie=attacker-session&ba_nonce=other',
        ),
        expectedNonce: nonce,
      ),
      isNull,
    );
    expect(
      BillingAuthRedirect.sessionCookieIfNonceMatches(
        callback: Uri.parse('myapp://auth/callback?ba_nonce=$nonce'),
        expectedNonce: nonce,
      ),
      isNull,
    );
  });

  test('session cookie is returned only when ba_nonce matches', () {
    const nonce = 'expected-nonce';
    expect(
      BillingAuthRedirect.sessionCookieIfNonceMatches(
        callback: Uri.parse(
          'myapp://auth/callback?cookie=legit-session&ba_nonce=$nonce',
        ),
        expectedNonce: nonce,
      ),
      'legit-session',
    );
  });

  test('BillingAuthClient.fromConfig rejects empty deepLinkScheme', () {
    expect(
      () => BillingAuthClient.fromConfig(
        const BillingSdkConfig(
          apiBaseUrl: 'https://billing.example.com',
          storagePrefix: 'test',
        ),
        storage: _MemoryAuthStorage(),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}

class _MemoryAuthStorage implements BillingAuthStorage {
  final Map<String, String> _items = {};

  @override
  Future<String?> getItem(String key) async => _items[key];

  @override
  Future<void> setItem(String key, String value) async => _items[key] = value;

  @override
  Future<void> removeItem(String key) async {
    _items.remove(key);
  }
}
