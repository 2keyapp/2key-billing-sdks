import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:two_key_dart_sdk/two_key_headless.dart';

void main() {
  late List<http.Request> requests;

  DelegatePermissionsClient client({Future<String?> Function()? accessToken}) =>
      DelegatePermissionsClient(
        billingBaseUrl: 'http://billing.test',
        sessionCookie: () async => 'ba_session=abc',
        accessToken: accessToken,
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode(
              r.url.path.endsWith('/entity')
                  ? {'exists': true}
                  : r.url.path.endsWith('/enroll-pull')
                  ? {'status': 'pending'}
                  : {
                      'enrollId': 'e1',
                      'pullToken': 'p1',
                      'subjectSki': 's1',
                      'kind': 'machine_source',
                      'status': 'pending',
                    },
            ),
            200,
          );
        }),
      );

  setUp(() => requests = []);

  test(
    'authenticated calls send the billing JWT with the session cookie',
    () async {
      final c = client(accessToken: () async => 'jwt-1');
      await c.entityExists(entityId: 'a@acme.test');
      await c.enrollCreate(
        entityId: 'a@acme.test',
        host: 'laptop--a@acme.test',
        csrPem: 'CSR',
        publicJwk: const {'kty': 'OKP'},
        kind: 'machine_source',
      );
      for (final r in requests) {
        expect(r.headers['authorization'], 'Bearer jwt-1', reason: r.url.path);
        expect(r.headers['cookie'], 'ba_session=abc', reason: r.url.path);
      }
    },
  );

  test('enroll-pull stays unauthenticated', () async {
    await client(accessToken: () async => 'jwt-1').enrollPull(pullToken: 'p1');
    expect(requests.single.headers.containsKey('authorization'), isFalse);
    expect(requests.single.headers.containsKey('cookie'), isFalse);
  });

  test(
    'no provider (or an empty token) sends no Authorization header',
    () async {
      await client().entityExists(entityId: 'a@acme.test');
      await client(
        accessToken: () async => '  ',
      ).entityExists(entityId: 'a@acme.test');
      expect(
        requests.every((r) => !r.headers.containsKey('authorization')),
        isTrue,
      );
    },
  );
}
