import 'config.dart';
import 'url.dart';

String _originSlash(String origin) =>
    origin.endsWith('/') ? origin : '$origin/';

String resolvedPortalBaseUrl(TwoKeySdkConfig config) {
  final c = config.validated();
  return c.resolvedPortalBaseUrl;
}

String shopUrl(TwoKeySdkConfig config) {
  final c = config.validated();
  final path = c.shopPath.replaceFirst(RegExp(r'^/'), '');
  return '${_originSlash(resolvedPortalBaseUrl(c))}$path';
}

String portalPathUrl(TwoKeySdkConfig config, String redirectPath) {
  final path =
      redirectPath.startsWith('/') ? redirectPath.substring(1) : redirectPath;
  return '${_originSlash(resolvedPortalBaseUrl(config))}$path';
}

String authBaseUrl(TwoKeySdkConfig config) {
  final c = config.validated();
  return '${_originSlash(c.apiBaseUrl)}api/auth';
}

/// Typedef for host OAuth browser / loopback / deep-link flow (Phase A).
typedef AuthSessionLauncher = Future<void> Function({
  required String authorizationUrl,
  required String callbackUrl,
});
