import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart' as c;
import 'package:pointycastle/export.dart' as pc;
import 'package:pointycastle/asn1.dart';
import 'package:two_key_dart_sdk/two_key_dart_sdk.dart';

/// Pure-Dart provider for tests only. The Scomm app installs an OpenSSL one.
final class TestBillingCrypto implements BillingCryptoProvider {
  const TestBillingCrypto();

  static void install() => BillingCryptoProvider.install(const TestBillingCrypto());

  @override
  Uint8List sha256(List<int> data) =>
      Uint8List.fromList(hash.sha256.convert(data).bytes);

  @override
  Uint8List randomBytes(int length) =>
      Uint8List.fromList(List<int>.generate(length, (_) => Random.secure().nextInt(256)));

  @override
  Future<Uint8List> ed25519PublicFromSeed(List<int> seed) async {
    final pair = await c.Ed25519().newKeyPairFromSeed(seed);
    return Uint8List.fromList((await pair.extractPublicKey()).bytes);
  }

  @override
  bool ecdsaP256Sha256Verify({
    required Uint8List spkiDer,
    required Uint8List message,
    required Uint8List rawSignature,
  }) {
    final spki = ASN1Parser(spkiDer).nextObject() as ASN1Sequence;
    final point = (spki.elements![1] as ASN1BitString).stringValues!;
    final domain = pc.ECDomainParameters('prime256v1');
    final key = pc.ECPublicKey(domain.curve.decodePoint(point), domain);
    final verifier = pc.ECDSASigner(pc.SHA256Digest())
      ..init(false, pc.PublicKeyParameter<pc.ECPublicKey>(key));
    final r = _int(rawSignature.sublist(0, 32));
    final s = _int(rawSignature.sublist(32));
    return verifier.verifySignature(message, pc.ECSignature(r, s));
  }

  static BigInt _int(List<int> b) => b.fold(BigInt.zero, (a, x) => (a << 8) | BigInt.from(x));
}
