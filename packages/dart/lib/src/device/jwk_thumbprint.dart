import 'dart:convert';

import 'package:crypto/crypto.dart';

/// RFC 7638 JWK thumbprint (SHA-256), base64url without padding.
///
/// Matches billing `calculateJwkThumbprint(jwk, "sha256")` (jose) for OKP keys.
String jwkThumbprintSha256(Map<String, dynamic> jwk) {
  final kty = '${jwk['kty'] ?? ''}';
  if (kty == 'OKP') {
    final crv = '${jwk['crv'] ?? ''}';
    final x = '${jwk['x'] ?? ''}';
    final canonical = '{"crv":"$crv","kty":"OKP","x":"$x"}';
    return _b64UrlSha256(canonical);
  }
  // Fallback: sort all non-private members for other key types.
  final members = <String, String>{};
  for (final e in jwk.entries) {
    if (e.key == 'd' || e.key == 'p' || e.key == 'q' || e.key == 'dp' ||
        e.key == 'dq' || e.key == 'qi' || e.key == 'oth' || e.key == 'k') {
      continue;
    }
    members[e.key] = jsonEncode(e.value);
  }
  final keys = members.keys.toList()..sort();
  final body = keys.map((k) => '"$k":${members[k]}').join(',');
  return _b64UrlSha256('{$body}');
}

String _b64UrlSha256(String canonicalUtf8) {
  final digest = sha256.convert(utf8.encode(canonicalUtf8));
  return base64Url.encode(digest.bytes).replaceAll('=', '');
}
