import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:two_key_dart_sdk/src/auth/billing_api_token_mint.dart';

void main() {
  group('BillingApiTokenMint.mintUsingPartyFromSessionCookie', () {
    test('binds me then remints after ORG_SLUG_REQUIRED', () async {
      final jwt = _fakeJwt({'sub': 'user-1', 'exp': _expSeconds(15)});
      final urls = <String>[];
      final client = MockClient((request) async {
        urls.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/token')) {
          final tokenGets =
              urls.where((u) => u.startsWith('GET ') && u.endsWith('/token')).length;
          if (tokenGets == 1) {
            return http.Response(
              jsonEncode({
                'code': 'ORG_SLUG_REQUIRED',
                'message': 'Bind an organization slug',
              }),
              403,
            );
          }
          return http.Response(jsonEncode({'token': jwt}), 200);
        }
        if (request.url.path.endsWith('/organization/bind')) {
          expect(request.headers['origin'], 'https://billing.example.com');
          expect(jsonDecode(request.body)['slug'], 'me');
          return http.Response(
            jsonEncode({
              'organizationId': 'org-1',
              'slug': 'me',
              'name': "Ada's Organization",
              'role': 'owner',
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final mint = BillingApiTokenMint(
        authBaseUrl: 'https://billing.example.com/api/auth',
        httpClient: client,
      );
      final tokens = await mint.mintUsingPartyFromSessionCookie('session=abc');
      expect(tokens.accessToken, jwt);
      expect(urls, [
        'GET /api/auth/token',
        'POST /api/auth/organization/bind',
        'GET /api/auth/token',
      ]);
      mint.close();
    });
  });
}

int _expSeconds(int minutes) =>
    DateTime.now().toUtc().add(Duration(minutes: minutes)).millisecondsSinceEpoch ~/
    1000;

String _fakeJwt(Map<String, Object?> payload) {
  String segment(Map<String, Object?> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  return '${segment({'alg': 'HS256'})}.${segment(payload)}.signature';
}
