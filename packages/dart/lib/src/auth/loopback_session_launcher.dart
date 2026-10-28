import 'dart:async';
import 'dart:io';

import 'billing_auth_session.dart';

/// Desktop [AuthSessionLauncher]: loopback HTTP callback + system browser.
///
/// Usage:
/// ```dart
/// final launcher = LoopbackAuthSessionLauncher();
/// final callback = await launcher.bind();
/// final auth = BillingAuthClient(..., sessionLauncher: launcher.call);
/// await auth.signInSocial(provider: 'google', callbackURL: callback.toString());
/// ```
class LoopbackAuthSessionLauncher {
  LoopbackAuthSessionLauncher({
    this.timeout = const Duration(minutes: 3),
    this.callbackPath = '/callback',
    Future<bool> Function(Uri url)? openBrowser,
  }) : _openBrowser = openBrowser ?? openSystemBrowser;

  final Duration timeout;
  final String callbackPath;
  final Future<bool> Function(Uri url) _openBrowser;

  HttpServer? _server;

  /// Binds an ephemeral loopback port. Returns the callback URL to hand to
  /// `signInSocial(callbackURL:)` (nonce is appended by the auth client).
  Future<Uri> bind() async {
    await close();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    return Uri(
      scheme: 'http',
      host: 'localhost',
      port: server.port,
      path: callbackPath,
    );
  }

  /// [AuthSessionLauncher] entry point.
  Future<Uri?> call({
    required Uri authorizationUrl,
    required Uri callbackUrl,
  }) async {
    final server = _server;
    if (server == null) {
      throw StateError('LoopbackAuthSessionLauncher.bind() not called');
    }
    final done = Completer<Uri?>();
    late StreamSubscription<HttpRequest> sub;
    sub = server.listen((req) async {
      if (req.uri.path != callbackUrl.path) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }
      req.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write('<!doctype html><html><body><h1>Signed in</h1>'
            '<p>You can return to the app.</p></body></html>');
      await req.response.close();
      if (!done.isCompleted) {
        // Re-anchor on the registered callback so nonce/host comparisons match.
        done.complete(callbackUrl.replace(query: req.uri.query));
      }
    }, onError: (Object e, StackTrace st) {
      if (!done.isCompleted) done.completeError(e, st);
    });

    try {
      if (!await _openBrowser(authorizationUrl)) {
        throw StateError('Could not open a browser for sign-in.');
      }
      return await done.future.timeout(timeout, onTimeout: () => null);
    } finally {
      await sub.cancel();
      await close();
    }
  }

  Future<void> close() async {
    final s = _server;
    _server = null;
    await s?.close(force: true);
  }

  /// Opens [url] with the OS default handler (Windows / macOS / Linux).
  static Future<bool> openSystemBrowser(Uri url) async {
    final target = url.toString();
    final ProcessResult result;
    if (Platform.isWindows) {
      result = await Process.run(
        'rundll32',
        ['url.dll,FileProtocolHandler', target],
      );
    } else if (Platform.isMacOS) {
      result = await Process.run('open', [target]);
    } else {
      result = await Process.run('xdg-open', [target]);
    }
    return result.exitCode == 0;
  }
}
