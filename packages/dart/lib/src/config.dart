import 'errors.dart';
import 'url.dart';

/// Host configuration — no product-brand defaults.
class TwoKeySdkConfig {
  const TwoKeySdkConfig({
    required this.apiBaseUrl,
    required this.publicKeyPem,
    required this.storagePrefix,
    this.portalBaseUrl,
    this.shopPath = '/shop',
    this.deepLinkScheme,
  });

  final String apiBaseUrl;
  final String publicKeyPem;
  final String storagePrefix;
  final String? portalBaseUrl;
  final String shopPath;
  final String? deepLinkScheme;

  TwoKeySdkConfig validated() {
    final origin = normalizeApiBaseUrl(apiBaseUrl);
    if (origin.isEmpty) {
      throw TwoKeyException(TwoKeyErrorCode.config, 'apiBaseUrl is required');
    }
    if (publicKeyPem.trim().isEmpty) {
      throw TwoKeyException(TwoKeyErrorCode.config, 'publicKeyPem is required');
    }
    if (storagePrefix.trim().isEmpty) {
      throw TwoKeyException(TwoKeyErrorCode.config, 'storagePrefix is required');
    }
    return TwoKeySdkConfig(
      apiBaseUrl: origin,
      publicKeyPem: publicKeyPem,
      storagePrefix: storagePrefix.trim(),
      portalBaseUrl: portalBaseUrl,
      shopPath: shopPath.trim().isEmpty ? '/shop' : shopPath,
      deepLinkScheme: deepLinkScheme,
    );
  }

  String get resolvedPortalBaseUrl {
    final p = portalBaseUrl?.trim();
    if (p != null && p.isNotEmpty) return normalizeApiBaseUrl(p);
    return apiBaseUrl;
  }
}
