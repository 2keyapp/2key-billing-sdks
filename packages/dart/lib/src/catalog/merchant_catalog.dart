/// Parsed merchant `catalog.json` for in-app shop listing (no live plans API).
///
/// Plans may list one offering (à la carte) or many (bundle). [shopSlug] is the
/// portal deep-link id: single-offering plans use `addonCode`; bundles use the
/// plan name (portal matches `plan.name`).
class MerchantCatalog {
  const MerchantCatalog({required this.plans});

  final List<MerchantShopPlan> plans;

  /// Parse seed-repo `catalog.json` (`products` → `plans` / `offerings`).
  factory MerchantCatalog.fromJson(Map<String, dynamic> json) {
    final productsRaw = json['products'];
    if (productsRaw is! Map) {
      throw FormatException('catalog.json products must be an object');
    }
    final plans = <MerchantShopPlan>[];
    productsRaw.forEach((productKey, productValue) {
      if (productKey is! String || productKey.isEmpty) return;
      if (productValue is! Map) {
        throw FormatException('products.$productKey must be an object');
      }
      final product = Map<String, dynamic>.from(productValue);
      final offeringNames = _offeringDisplayNames(product['offerings']);
      final plansRaw = product['plans'];
      if (plansRaw is! Map) {
        throw FormatException('products.$productKey.plans must be an object');
      }
      plansRaw.forEach((planKey, planValue) {
        if (planKey is! String || planKey.isEmpty) return;
        if (planValue is! Map) {
          throw FormatException(
            'products.$productKey.plans.$planKey must be an object',
          );
        }
        plans.add(
          MerchantShopPlan.fromJson(
            productName: productKey,
            name: planKey,
            json: Map<String, dynamic>.from(planValue),
            offeringDisplayNames: offeringNames,
          ),
        );
      });
    });
    return MerchantCatalog(plans: List.unmodifiable(plans));
  }

  static Map<String, String> _offeringDisplayNames(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, String>{};
    raw.forEach((key, value) {
      if (key is! String || key.isEmpty || value is! Map) return;
      final display = value['displayName'];
      out[key] = display is String && display.trim().isNotEmpty
          ? display.trim()
          : key;
    });
    return out;
  }
}

/// One commercial plan row from `catalog.json` (single SKU or bundle).
class MerchantShopPlan {
  const MerchantShopPlan({
    required this.productName,
    required this.name,
    required this.offeringCodes,
    required this.pricings,
    this.description,
    this.trialDays = 0,
    this.offeringDisplayNames = const {},
  });

  final String productName;
  final String name;
  final String? description;
  final int trialDays;
  final List<String> offeringCodes;
  final List<MerchantPlanPricing> pricings;
  final Map<String, String> offeringDisplayNames;

  bool get isBundle => offeringCodes.length > 1;

  /// Stable addon code when this plan is exactly one offering.
  String? get singleAddonCode =>
      offeringCodes.length == 1 ? offeringCodes.first : null;

  /// Portal `/shop/{slug}` id — addon code for singles, plan name for bundles.
  String get shopSlug {
    final code = singleAddonCode?.trim();
    if (code != null && code.isNotEmpty) return code;
    return name;
  }

  factory MerchantShopPlan.fromJson({
    required String productName,
    required String name,
    required Map<String, dynamic> json,
    Map<String, String> offeringDisplayNames = const {},
  }) {
    final codesRaw = json['offeringCodes'];
    if (codesRaw is! List || codesRaw.isEmpty) {
      throw FormatException('plan "$name" offeringCodes must be a non-empty array');
    }
    final offeringCodes = <String>[];
    for (final item in codesRaw) {
      if (item is! String || item.trim().isEmpty) {
        throw FormatException('plan "$name" offeringCodes must be strings');
      }
      offeringCodes.add(item.trim());
    }

    final pricingsRaw = json['pricings'];
    if (pricingsRaw is! Map || pricingsRaw.isEmpty) {
      throw FormatException('plan "$name" pricings must be a non-empty object');
    }
    final pricings = <MerchantPlanPricing>[];
    pricingsRaw.forEach((interval, body) {
      if (interval is! String || interval.trim().isEmpty) return;
      if (body is! Map) {
        throw FormatException('plan "$name" pricings.$interval must be an object');
      }
      final map = Map<String, dynamic>.from(body);
      final currency = map['currency'];
      final basePrice = map['basePrice'] ?? map['base_price'];
      if (currency is! String || currency.trim().isEmpty) {
        throw FormatException('plan "$name" pricings.$interval.currency required');
      }
      if (basePrice is! num) {
        throw FormatException('plan "$name" pricings.$interval.basePrice required');
      }
      pricings.add(
        MerchantPlanPricing(
          billingInterval: interval.trim(),
          currency: currency.trim(),
          basePrice: basePrice.toDouble(),
        ),
      );
    });
    if (pricings.isEmpty) {
      throw FormatException('plan "$name" has no valid pricings');
    }

    final trialRaw = json['trialDays'] ?? json['trial_days'];
    final trialDays = trialRaw is num
        ? trialRaw.toInt()
        : trialRaw is String
        ? int.tryParse(trialRaw) ?? 0
        : 0;

    final description = json['description'];
    return MerchantShopPlan(
      productName: productName,
      name: name,
      description: description is String ? description : null,
      trialDays: trialDays < 0 ? 0 : trialDays,
      offeringCodes: List.unmodifiable(offeringCodes),
      pricings: List.unmodifiable(pricings),
      offeringDisplayNames: Map.unmodifiable(offeringDisplayNames),
    );
  }
}

class MerchantPlanPricing {
  const MerchantPlanPricing({
    required this.billingInterval,
    required this.currency,
    required this.basePrice,
  });

  final String billingInterval;
  final String currency;
  final double basePrice;
}
