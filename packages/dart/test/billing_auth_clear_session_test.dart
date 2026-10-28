import 'package:flutter_test/flutter_test.dart';
import 'package:two_key_dart_sdk/src/auth/billing_auth_client.dart';
import 'package:two_key_dart_sdk/src/auth/billing_auth_storage.dart';

class _MemStorage implements BillingAuthStorage {
  final map = <String, String>{};
  @override
  Future<String?> getItem(String key) async => map[key];
  @override
  Future<void> setItem(String key, String value) async => map[key] = value;
  @override
  Future<void> removeItem(String key) async => map.remove(key);
}

void main() {
  test('clearLocalAuthSession removes the cookie and session cache keys',
      () async {
    final storage = _MemStorage()
      ..map['idr.source.auth_cookie'] = '{"better-auth.session_token":{}}'
      ..map['idr.source.auth_session_data'] = '{"user":{}}'
      ..map['idr.source.identity'] = '{"ski":"member"}';
    final client = BillingAuthClient(
      billingBaseUrl: 'http://127.0.0.1:3000',
      deepLinkScheme: 'idr',
      storage: storage,
      storagePrefix: 'idr.source.auth',
    );
    client.setOnline(false);

    await client.clearLocalAuthSession();

    expect(storage.map.keys, ['idr.source.identity']);
  });
}
