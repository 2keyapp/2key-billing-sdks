import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:two_key_dart_sdk/two_key_dart_sdk.dart';

void main() {
  test('loopback launcher returns callback with query from browser redirect',
      () async {
    final launcher = LoopbackAuthSessionLauncher(
      openBrowser: (url) async {
        // Simulate the auth server redirecting the browser back.
        final redirect = Uri.parse(url.queryParameters['cb']!)
            .replace(queryParameters: {'cookie': 'c=1', 'ba_nonce': 'n1'});
        // ignore: unawaited_futures
        http.get(redirect);
        return true;
      },
    );
    final base = await launcher.bind();
    final callback = base.replace(queryParameters: {'ba_nonce': 'n1'});
    final result = await launcher.call(
      authorizationUrl: Uri.parse('http://auth.test/proxy')
          .replace(queryParameters: {'cb': callback.toString()}),
      callbackUrl: callback,
    );
    expect(result, isNotNull);
    expect(result!.queryParameters['cookie'], 'c=1');
    expect(result.queryParameters['ba_nonce'], 'n1');
    expect(result.port, base.port);
  });

  test('loopback launcher returns null on timeout', () async {
    final launcher = LoopbackAuthSessionLauncher(
      timeout: const Duration(milliseconds: 200),
      openBrowser: (_) async => true,
    );
    final cb = await launcher.bind();
    final result = await launcher.call(
      authorizationUrl: Uri.parse('http://auth.test/proxy'),
      callbackUrl: cb,
    );
    expect(result, isNull);
  });
}
