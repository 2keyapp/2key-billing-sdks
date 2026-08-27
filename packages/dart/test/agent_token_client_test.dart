import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:two_key_dart_sdk/two_key_dart_sdk.dart';

void main() {
  test('mintAgentToken posts to /api/auth/agent/token', () async {
    String? capturedPath;
    Map<String, dynamic>? capturedBody;

    final client = AgentTokenClient(
      authOrigin: 'https://auth.example.com',
      httpClient: MockClient((request) async {
        capturedPath = request.url.path;
        capturedBody = jsonDecode(utf8.decode(request.bodyBytes))
            as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'token': 'jwt-token',
              'expiresIn': 3600,
              'token_type': 'Bearer',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.mintAgentToken(
      credential: {'ski': 'ski123', 'kind': 'machine'},
      proof: {'ts': 1785736800, 'signature': 'sig'},
      targetIdentity: 'target-pubkey',
    );

    expect(capturedPath, '/api/auth/agent/token');
    expect(capturedBody?['targetIdentity'], 'target-pubkey');
    expect(result.token, 'jwt-token');
    expect(result.expiresIn, 3600);

    client.close();
  });
}
