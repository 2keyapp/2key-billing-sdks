import 'dart:typed_data';

/// Crypto the SDK needs, supplied by the host app.
///
/// The SDK ships no crypto implementation. The host installs one backed by a
/// single library (the Scomm app uses OpenSSL) before any license or device
/// call.
abstract interface class BillingCryptoProvider {
  Uint8List sha256(List<int> data);

  Uint8List randomBytes(int length);

  /// Ed25519 public key for a 32-byte [seed].
  Future<Uint8List> ed25519PublicFromSeed(List<int> seed);

  /// ECDSA P-256 / SHA-256. [spkiDer] is a SubjectPublicKeyInfo and
  /// [rawSignature] is the JWS `r || s` form. A bad signature is `false`.
  bool ecdsaP256Sha256Verify({
    required Uint8List spkiDer,
    required Uint8List message,
    required Uint8List rawSignature,
  });

  static BillingCryptoProvider? _installed;

  static void install(BillingCryptoProvider provider) {
    _installed = provider;
  }

  static BillingCryptoProvider get current =>
      _installed ??
      (throw StateError(
        'BillingCryptoProvider.install must run before using the billing SDK.',
      ));

  /// Test hook.
  static void resetForTesting() => _installed = null;
}
