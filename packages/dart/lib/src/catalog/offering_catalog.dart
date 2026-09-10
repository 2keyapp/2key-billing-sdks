/// Host-declared product / offering / add-on codes this binary knows how to gate.
///
/// At runtime, [LicenseEntitlements] intersects this set with the verified license
/// JWT. Unknown JWT codes are ignored; catalog codes missing from the JWT fail closed.
/// Omit the catalog to keep JWT-only gating.
///
/// Bake seed-repo `hosts.json` at build time (`HostsCatalog.forHost`) into
/// `BillingSdkConfig.catalog`. Product identity is the catalog **name**
/// ([productNames], e.g. `Scomm`), not a Postgres serial id.
class OfferingCatalog {
  const OfferingCatalog({
    this.productNames = const {},
    this.productIds = const {},
    required this.offeringCodes,
    required this.addonCodes,
  });

  /// Catalog product names this binary gates (`hosts.json` `productNames`).
  final Set<String> productNames;

  /// Legacy identity strings (JWT `product_id` / fixture aliases).
  /// Prefer [productNames] from baked `hosts.json`.
  final Set<String> productIds;

  final Set<String> offeringCodes;
  final Set<String> addonCodes;

  /// True when [productId] is a catalog name or legacy id.
  bool knowsProduct(String productId) {
    final key = productId.trim();
    if (key.isEmpty) return false;
    return productNames.contains(key) || productIds.contains(key);
  }

  /// True when [offeringCode] is in this catalog.
  bool knowsOffering(String offeringCode) =>
      offeringCodes.contains(offeringCode.trim());

  /// True when [addonCode] matches a catalog add-on (case-insensitive).
  bool knowsAddon(String addonCode) {
    final needle = addonCode.trim().toLowerCase();
    return addonCodes.any((a) => a.toLowerCase() == needle);
  }
}
