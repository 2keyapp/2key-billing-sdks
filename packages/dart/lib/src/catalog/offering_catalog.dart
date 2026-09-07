/// Host-declared product / offering / add-on codes this binary knows how to gate.
///
/// At runtime, [LicenseEntitlements] intersects this set with the verified license
/// JWT. Unknown JWT codes are ignored; catalog codes missing from the JWT fail closed.
/// Omit the catalog to keep JWT-only gating.
///
/// Codes are tenant strings (not an enum). Scomm Email / Office membership is
/// documented in `conformance/fixtures/scomm_host_catalogs.json`.
class OfferingCatalog {
  const OfferingCatalog({
    required this.productIds,
    required this.offeringCodes,
    required this.addonCodes,
  });

  final Set<String> productIds;
  final Set<String> offeringCodes;
  final Set<String> addonCodes;

  /// True when [productId] is in this catalog.
  bool knowsProduct(String productId) => productIds.contains(productId);

  /// True when [offeringCode] is in this catalog.
  bool knowsOffering(String offeringCode) =>
      offeringCodes.contains(offeringCode.trim());

  /// True when [addonCode] matches a catalog add-on (case-insensitive).
  bool knowsAddon(String addonCode) {
    final needle = addonCode.trim().toLowerCase();
    return addonCodes.any((a) => a.toLowerCase() == needle);
  }
}
