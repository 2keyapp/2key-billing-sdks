import '../catalog/offering_catalog.dart';
import '../session/license_entitlements.dart';

/// Build-time configuration for using-party billing integration.
///
/// Host apps map dart-defines / env into this object, then call
/// [BillingSdk.configureFrom]. Construct [BillingAuthClient.fromConfig] only
/// when the host performs billing-profile SSO; using-party apps that paste an
/// offline license JWT SHOULD omit [deepLinkScheme].
class BillingSdkConfig {
  const BillingSdkConfig({
    required this.apiBaseUrl,
    required this.storagePrefix,
    this.deepLinkScheme = '',
    this.publicKeyPem,
    this.publicKeyAsset,
    this.portalBaseUrl,
    this.shopPath = '/shop',
    this.licensePollInterval = defaultLicensePollInterval,
    this.addonPlanNameHints = const {},
    this.catalog,
  });

  /// Billing server origin (e.g. `https://billing.example.com`).
  /// Trailing `/api/v1` is normalized away.
  final String apiBaseUrl;

  /// App deep-link scheme for social OAuth callbacks (e.g. `myapp`).
  ///
  /// Empty when the host does not run Better Auth / profile SSO. [BillingAuthClient]
  /// requires a non-empty value.
  final String deepLinkScheme;

  /// Single namespace for auth cookie storage and session keys.
  ///
  /// Must be the same value used for [SecureBillingAuthStorage] and
  /// [SecureBillingSessionStore].
  final String storagePrefix;

  /// EC public key PEM (ES256) for license JWT verification.
  final String? publicKeyPem;

  /// Flutter asset path for the license public key (alternative to [publicKeyPem]).
  final String? publicKeyAsset;

  /// Portal / shop web origin. Defaults to [apiBaseUrl] when null/empty.
  final String? portalBaseUrl;

  /// Marketplace path appended to the portal origin (default `/shop`).
  final String shopPath;

  /// Background license poll interval (default 6 hours).
  final Duration licensePollInterval;

  /// Host product plan-name hints for numeric plan IDs in license JWTs.
  /// Empty by default — supply product-specific maps in the host app.
  final Map<String, List<String>> addonPlanNameHints;

  /// Static offerings this binary can gate. Intersected with the verified JWT.
  /// Bake the tenant’s `hosts.json` via `HostsCatalog.forHost`. When null,
  /// [LicenseEntitlements] uses JWT claims only.
  final OfferingCatalog? catalog;

  /// Resolved portal origin (explicit [portalBaseUrl] or [apiBaseUrl]).
  String get resolvedPortalBaseUrl {
    final portal = portalBaseUrl?.trim() ?? '';
    if (portal.isNotEmpty) return portal;
    return apiBaseUrl;
  }
}
