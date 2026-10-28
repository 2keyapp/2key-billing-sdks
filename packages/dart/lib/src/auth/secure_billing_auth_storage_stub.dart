import 'billing_auth_storage.dart';

/// Dart VM stand-in: no Flutter, no secure enclave. Pass your own
/// [BillingAuthStorage] (e.g. a file-backed one) instead.
class SecureBillingAuthStorage implements BillingAuthStorage {
  SecureBillingAuthStorage({Object? storage, required this.storagePrefix});

  final String storagePrefix;

  Never _unsupported() => throw UnsupportedError(
        'SecureBillingAuthStorage needs Flutter; supply a BillingAuthStorage.',
      );

  @override
  Future<String?> getItem(String key) => _unsupported();

  @override
  Future<void> setItem(String key, String value) => _unsupported();

  @override
  Future<void> removeItem(String key) => _unsupported();
}
