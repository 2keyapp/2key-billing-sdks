import '../catalog/offering_catalog.dart';
import 'billing_subscription.dart';
import 'billing_token_payload.dart';
import 'jwt_payload_keys.dart';

/// Using-party feature gates: **Product → Feature → `{ count, …resources }`**.
///
/// Default GROUP BY is COUNT(*) of granted offering units (`quantity × units`)
/// as `count` per addon/offering code. Other numeric resources are SUM'd on
/// that same feature. Prefer server `entitlements.products` when present.
/// Never exposes prices. Apps should query [toNormalizedJson] on start.
class LicenseEntitlements {
  const LicenseEntitlements._({
    required this.payload,
    required this.products,
    required this.byProduct,
    required this.addons,
    required this.offeringCodes,
    required this.subscriptions,
  });

  final BillingTokenPayload payload;

  /// product → feature (addon/offering) → `{ count, mailbox, … }`.
  final Map<String, Map<String, Map<String, int>>> products;

  /// productId → resourceKey → summed quantity (no `count`).
  final Map<String, Map<String, int>> byProduct;
  final Set<String> addons;
  final Set<String> offeringCodes;

  /// Seats this host may show (`catalog ∩ JWT`). Raw JWT remains on
  /// [BillingTokenPayload.subscriptions] for device bind.
  final List<BillingSubscription> subscriptions;

  /// Build from a verified [BillingTokenPayload].
  ///
  /// When [catalog] is set, product / offering / add-on sets **and**
  /// [subscriptions] are intersected with the host catalog (fail-closed).
  /// Unknown JWT codes are dropped. [BillingTokenPayload.subscriptions]
  /// stays the raw JWT for device bind.
  factory LicenseEntitlements.fromPayload(
    BillingTokenPayload payload, {
    OfferingCatalog? catalog,
  }) {
    var products = <String, Map<String, Map<String, int>>>{};
    var byProduct = <String, Map<String, int>>{};
    final addons = <String>{};
    final offerings = <String>{};

    void addResource(String productKey, String resourceKey, int amount) {
      if (productKey.isEmpty || amount <= 0) return;
      if (_nonResourceKeys.contains(resourceKey) || resourceKey == 'count') {
        return;
      }
      final bucket = byProduct.putIfAbsent(productKey, () => <String, int>{});
      bucket[resourceKey] = (bucket[resourceKey] ?? 0) + amount;
    }

    void addFeature(
      String productKey,
      String featureKey,
      String resourceKey,
      int amount,
    ) {
      if (productKey.isEmpty || featureKey.isEmpty || amount <= 0) return;
      if (resourceKey != 'count' && _nonResourceKeys.contains(resourceKey)) {
        return;
      }
      final features =
          products.putIfAbsent(productKey, () => <String, Map<String, int>>{});
      final bucket = features.putIfAbsent(featureKey, () => <String, int>{});
      bucket[resourceKey] = (bucket[resourceKey] ?? 0) + amount;
    }

    final server = payload.entitlementsJson;
    var usedServerByProduct = false;
    var usedServerProducts = false;
    if (server != null && payload.payloadVersion >= 3) {
      final rawProducts = server['products'];
      if (rawProducts is Map) {
        rawProducts.forEach((productKey, features) {
          if (productKey is! String || productKey.isEmpty) return;
          if (features is! Map) return;
          var nested = false;
          features.forEach((_, bucket) {
            if (bucket is Map) nested = true;
          });
          if (!nested) return;
          usedServerProducts = true;
          features.forEach((featureKey, bucket) {
            if (featureKey is! String || featureKey.isEmpty) return;
            if (bucket is! Map) return;
            bucket.forEach((resourceKey, value) {
              if (resourceKey is! String) return;
              final n = parseInt(value);
              if (n != null && n > 0) {
                addFeature(productKey, featureKey, resourceKey, n);
              }
            });
          });
        });
      }
      final rawByProduct = server['by_product'] ?? server['byProduct'];
      if (rawByProduct is Map) {
        usedServerByProduct = true;
        rawByProduct.forEach((productKey, resources) {
          if (productKey is! String || productKey.isEmpty) return;
          if (resources is! Map) return;
          resources.forEach((resourceKey, value) {
            if (resourceKey is! String) return;
            final n = parseInt(value);
            if (n != null && n > 0) {
              addResource(productKey, resourceKey, n);
            }
          });
        });
      }
      final addonsRaw = server['addons'];
      if (addonsRaw is List) {
        for (final a in addonsRaw) {
          if (a is String && a.isNotEmpty) addons.add(a);
        }
      }
      final byOffering = server['by_offering_code'] ?? server['byOfferingCode'];
      if (byOffering is Map) {
        byOffering.forEach((k, v) {
          if (k is String && k.isNotEmpty) offerings.add(k);
          if (v is Map) {
            final addon = v['addon_code'] ?? v['addonCode'];
            if (addon is String && addon.isNotEmpty) addons.add(addon);
          }
        });
      }
    }

    final now = DateTime.now();
    for (final s in payload.subscriptions) {
      if (!s.isActive || s.validUntil.isBefore(now)) continue;
      if (s.addonCode != null && s.addonCode!.isNotEmpty) {
        addons.add(s.addonCode!);
      }
      for (final o in s.offerings) {
        offerings.add(o.offeringCode);
        final a = o.addonCode;
        if (a != null) addons.add(a);
      }

      if (usedServerByProduct && usedServerProducts) continue;

      final q = s.quantity < 1 ? 1 : s.quantity;
      if (s.offerings.isNotEmpty) {
        for (final o in s.offerings) {
          final units = o.units < 1 ? 1 : o.units;
          final multiplier = units * q;
          final productKey = _productGroupKey(o);
          final featureKey = _featureGroupKey(o);
          if (!usedServerProducts) {
            addFeature(productKey, featureKey, 'count', multiplier);
          }
          o.resources.forEach((key, value) {
            final n = parseInt(value);
            if (n != null && n > 0 && productKey.isNotEmpty) {
              if (!usedServerByProduct) {
                addResource(productKey, key, n * multiplier);
              }
              if (!usedServerProducts) {
                addFeature(productKey, featureKey, key, n * multiplier);
              }
            }
          });
        }
      } else if (s.productName.isNotEmpty || s.productId.isNotEmpty) {
        final productKey =
            s.productName.isNotEmpty ? s.productName : s.productId;
        final featureKey =
            (s.addonCode != null && s.addonCode!.isNotEmpty)
                ? s.addonCode!
                : productKey;
        if (!usedServerProducts) {
          addFeature(productKey, featureKey, 'count', q);
        }
        if (s.maxDevices != null && s.maxDevices! > 0) {
          if (!usedServerByProduct) {
            addResource(productKey, 'max_devices', s.maxDevices! * q);
          }
          if (!usedServerProducts) {
            addFeature(productKey, featureKey, 'max_devices', s.maxDevices! * q);
          }
        }
      }
    }

    if (catalog != null) {
      byProduct = _applyCatalogToByProduct(byProduct, payload, catalog);
      products = _applyCatalogToProducts(products, payload, catalog);
      addons.removeWhere((a) => !catalog.knowsAddon(a));
      offerings.removeWhere((c) => !catalog.knowsOffering(c));
    }

    final visibleSubs = catalog == null
        ? payload.subscriptions
        : payload.subscriptions
            .where((s) => s.isAllowedByCatalog(catalog))
            .toList(growable: false);

    return LicenseEntitlements._(
      payload: payload,
      products: Map<String, Map<String, Map<String, int>>>.unmodifiable(
        products.map(
          (k, features) => MapEntry(
            k,
            Map<String, Map<String, int>>.unmodifiable(
              features.map(
                (fk, bucket) => MapEntry(
                  fk,
                  Map<String, int>.unmodifiable(bucket),
                ),
              ),
            ),
          ),
        ),
      ),
      byProduct: Map.unmodifiable(
        byProduct.map(
          (k, v) => MapEntry(k, Map<String, int>.unmodifiable(v)),
        ),
      ),
      addons: Set.unmodifiable(addons),
      offeringCodes: Set.unmodifiable(offerings),
      subscriptions: List.unmodifiable(visibleSubs),
    );
  }

  /// Product → feature → `{ count, …resources }`. No prices, no plan rows.
  Map<String, Object?> toNormalizedJson() => {
        'products': {
          for (final product in products.entries)
            product.key: {
              for (final feature in product.value.entries)
                feature.key: Map<String, int>.from(feature.value),
            },
        },
      };

  /// Product keys present in the gate JSON or the flat SUM map.
  Set<String> get productIds => {...products.keys, ...byProduct.keys};

  bool get hasAnyActiveSubscription =>
      subscriptions.any((s) => s.isActive && !s.isPeriodEnded);

  bool hasOffering(String offeringCode) =>
      offeringCodes.contains(offeringCode.trim());

  bool hasAddon(String addonCode) {
    final needle = addonCode.trim().toLowerCase();
    return addons.any((a) => a.toLowerCase() == needle);
  }

  bool hasProduct(String productId) =>
      products.containsKey(productId) || byProduct.containsKey(productId);

  bool hasPlan(String planId) =>
      subscriptions.any((s) => s.isActive && s.planId == planId && !s.isPeriodEnded);

  /// Quantity of [resourceKey] for one product (0 when absent).
  int resourceForProduct(
    String productId,
    String resourceKey, {
    int defaultValue = 0,
  }) {
    return byProduct[productId]?[resourceKey] ?? defaultValue;
  }

  /// Sum of [resourceKey] across **all** products.
  int resourceInt(String key, {int defaultValue = 0}) {
    var total = 0;
    var found = false;
    for (final resources in byProduct.values) {
      final n = resources[key];
      if (n != null) {
        found = true;
        total += n;
      }
    }
    return found ? total : defaultValue;
  }

  int maxDevices({int defaultValue = 0}) =>
      resourceInt('max_devices', defaultValue: defaultValue);

  int maxDevicesForProduct(String productId, {int defaultValue = 0}) =>
      resourceForProduct(productId, 'max_devices', defaultValue: defaultValue);

  DateTime? earliestExpiry() {
    DateTime? soonest;
    for (final s in subscriptions) {
      if (!s.isActive || s.isPeriodEnded) continue;
      if (soonest == null || s.validUntil.isBefore(soonest)) {
        soonest = s.validUntil;
      }
    }
    return soonest;
  }

  DateTime? expiryForProduct(String productId) {
    final id = productId.trim();
    DateTime? soonest;
    for (final s in subscriptions) {
      if (!s.isActive || s.isPeriodEnded) continue;
      final hit = s.productId == id ||
          s.productName == id ||
          s.offerings.any(
            (o) =>
                o.productId == id ||
                o.productCode == id ||
                o.productName == id,
          );
      if (!hit) continue;
      if (soonest == null || s.validUntil.isBefore(soonest)) {
        soonest = s.validUntil;
      }
    }
    return soonest;
  }

  DateTime? expiryForAddon(String addonCode) {
    final needle = addonCode.trim().toLowerCase();
    DateTime? soonest;
    for (final s in subscriptions) {
      if (!s.isActive || s.isPeriodEnded) continue;
      if (!s.matchesAddonRef(needle)) continue;
      if (soonest == null || s.validUntil.isBefore(soonest)) {
        soonest = s.validUntil;
      }
    }
    return soonest;
  }

  DateTime? expiryForOffering(String offeringCode) {
    final code = offeringCode.trim();
    DateTime? soonest;
    for (final s in subscriptions) {
      if (!s.isActive || s.isPeriodEnded) continue;
      if (!s.offerings.any((o) => o.offeringCode == code)) continue;
      if (soonest == null || s.validUntil.isBefore(soonest)) {
        soonest = s.validUntil;
      }
    }
    return soonest;
  }

  bool allowsDevice(String localSki) {
    final active = payload.activeSubscriptions.where((s) => !s.isPeriodEnded);
    var sawBound = false;
    for (final s in active) {
      if (s.devices.isEmpty) continue;
      sawBound = true;
      if (s.allowsDevice(localSki)) return true;
    }
    return !sawBound;
  }
}

const _nonResourceKeys = {
  'addon_code',
  'addonCode',
  'surfaces',
  'platforms',
  'usage_grants',
  'usageGrants',
};

/// Catalog product name, then code, then serial id — one key so SUM does not double-count.
String _productGroupKey(LicenseOfferingClaim offering) {
  final name = offering.productName?.trim();
  if (name != null && name.isNotEmpty) return name;
  final code = offering.productCode?.trim();
  if (code != null && code.isNotEmpty) return code;
  return offering.productId.trim();
}

String _featureGroupKey(LicenseOfferingClaim offering) {
  final addon = offering.addonCode?.trim();
  if (addon != null && addon.isNotEmpty) return addon;
  return offering.offeringCode.trim();
}

List<String> _subscriptionProductAliases(BillingSubscription sub) {
  final aliases = <String>[];
  void push(String? value) {
    final n = value?.trim() ?? '';
    if (n.isNotEmpty && !aliases.contains(n)) aliases.add(n);
  }

  push(sub.productId);
  push(sub.productName);
  for (final offering in sub.offerings) {
    push(offering.productId);
    push(offering.productCode);
    push(offering.productName);
  }
  return aliases;
}

/// Keep catalog-known keys only. Remap JWT serial `product_id` onto `product_name`
/// when the baked catalog lists names. Do not duplicate buckets (resourceInt).
Map<String, Map<String, int>> _applyCatalogToByProduct(
  Map<String, Map<String, int>> byProduct,
  BillingTokenPayload payload,
  OfferingCatalog catalog,
) {
  final next = <String, Map<String, int>>{};
  byProduct.forEach((key, bucket) {
    if (catalog.knowsProduct(key)) next[key] = bucket;
  });
  for (final sub in payload.subscriptions) {
    final aliases = _subscriptionProductAliases(sub);
    String? sourceKey;
    for (final alias in aliases) {
      if (byProduct.containsKey(alias)) {
        sourceKey = alias;
        break;
      }
    }
    if (sourceKey == null) continue;
    final bucket = byProduct[sourceKey]!;
    for (final alias in aliases) {
      if (!catalog.knowsProduct(alias)) continue;
      next.putIfAbsent(alias, () => bucket);
    }
  }
  return next;
}

Map<String, Map<String, Map<String, int>>> _applyCatalogToProducts(
  Map<String, Map<String, Map<String, int>>> products,
  BillingTokenPayload payload,
  OfferingCatalog catalog,
) {
  bool knowsFeature(String code) =>
      catalog.knowsAddon(code) || catalog.knowsOffering(code);

  Map<String, Map<String, int>> filterFeatures(
    Map<String, Map<String, int>> features,
  ) {
    final next = <String, Map<String, int>>{};
    features.forEach((code, bucket) {
      if (knowsFeature(code)) next[code] = bucket;
    });
    return next;
  }

  final next = <String, Map<String, Map<String, int>>>{};
  products.forEach((key, features) {
    if (!catalog.knowsProduct(key)) return;
    final filtered = filterFeatures(features);
    if (filtered.isNotEmpty) next[key] = filtered;
  });
  for (final sub in payload.subscriptions) {
    final aliases = _subscriptionProductAliases(sub);
    String? sourceKey;
    for (final alias in aliases) {
      if (products.containsKey(alias)) {
        sourceKey = alias;
        break;
      }
    }
    if (sourceKey == null) continue;
    final filtered = filterFeatures(products[sourceKey]!);
    if (filtered.isEmpty) continue;
    for (final alias in aliases) {
      if (!catalog.knowsProduct(alias)) continue;
      next.putIfAbsent(alias, () => filtered);
    }
  }
  return next;
}
