import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'billing_auth_storage.dart';

/// [BillingAuthStorage] backed by [FlutterSecureStorage].
class SecureBillingAuthStorage implements BillingAuthStorage {
  SecureBillingAuthStorage({
    FlutterSecureStorage? storage,
    required this.storagePrefix,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final String storagePrefix;

  String _key(String name) => '$storagePrefix:$name';

  @override
  Future<String?> getItem(String key) => _storage.read(key: _key(key));

  @override
  Future<void> setItem(String key, String value) =>
      _storage.write(key: _key(key), value: value);

  @override
  Future<void> removeItem(String key) => _storage.delete(key: _key(key));
}
