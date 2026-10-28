// Flutter-free interface; the FlutterSecureStorage impl is only linked when
// `dart:ui` exists so headless Dart VM hosts (CLIs, daemons) can use auth.
export 'secure_billing_auth_storage_stub.dart'
    if (dart.library.ui) 'secure_billing_auth_storage_flutter.dart';

/// Persists auth session secrets for [BillingAuthClient].
///
/// Host apps implement this or use [SecureBillingAuthStorage]. Do not depend on
/// Better Auth's `AuthStorage` — that type stays inside the SDK.
abstract interface class BillingAuthStorage {
  Future<String?> getItem(String key);
  Future<void> setItem(String key, String value);
  Future<void> removeItem(String key);
}
