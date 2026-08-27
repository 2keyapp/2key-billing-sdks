import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:two_key_dart_sdk/two_key_dart_sdk.dart';

void main() {
  group('MachineAuthnClient', () {
    test('enrollCreate posts to /api/v1/machine-authn/enroll-create', () async {
      String? capturedPath;
      Map<String, dynamic>? capturedBody;

      final client = MachineAuthnClient(
        baseUrl: 'https://billing.example.com',
        authorization: 'sess-token',
        httpClient: MockClient((request) async {
          capturedPath = request.url.path;
          capturedBody = jsonDecode(utf8.decode(request.bodyBytes))
              as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': {
                'enrollId': '550e8400-e29b-41d4-a716-446655440000',
                'pullToken': 'ptok_abc',
                'subjectSki': 'ski123',
                'status': 'pending',
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await client.enrollCreate(
        payingPartyId: '1',
        memberId: 'member-1',
        csrPem: '-----BEGIN CERTIFICATE REQUEST-----\nMIIB\n-----END CERTIFICATE REQUEST-----',
        subjectSki: 'ski123',
        host: 'camera.acme.idr.to',
      );

      expect(capturedPath, '/api/v1/machine-authn/enroll-create');
      expect(capturedBody?['csrPem'], contains('CERTIFICATE REQUEST'));
      expect(capturedBody?['payingPartyId'], '1');
      expect(result.pullToken, 'ptok_abc');
      expect(result.status, 'pending');

      client.close();
    });

    test('enrollPull is unauthenticated', () async {
      String? authHeader;

      final client = MachineAuthnClient(
        baseUrl: 'https://billing.example.com/api/v1',
        authorization: 'should-not-send',
        httpClient: MockClient((request) async {
          authHeader = request.headers['authorization'];
          return http.Response(
            jsonEncode({
              'data': {'status': 'pending', 'enrollId': 'id-1'},
            }),
            200,
          );
        }),
      );

      final result = await client.enrollPull(pullToken: 'ptok');
      expect(result, isA<EnrollPullPending>());
      expect(authHeader, isNull);

      client.close();
    });

    test('platformRoot GETs public path', () async {
      String? capturedPath;

      final client = MachineAuthnClient(
        baseUrl: 'https://billing.example.com',
        httpClient: MockClient((request) async {
          capturedPath = request.url.path;
          return http.Response(
            jsonEncode({'data': {'publicJwk': {'kty': 'OKP'}}}),
            200,
          );
        }),
      );

      await client.platformRoot();
      expect(capturedPath, '/api/v1/machine-authn/platform-root');

      client.close();
    });
  });
}
