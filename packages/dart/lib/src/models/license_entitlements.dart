import '../catalog/offering_catalog.dart';
import 'billing_subscription.dart';
import 'billing_token_payload.dart';
import 'jwt_payload_keys.dart';

/// Using-party feature gates: **Product → Resources → Quantity**.
///
/// Quantities for the same product are summed across offerings/plans.
/// Prefer server `entitlements.by_product` when `payload_version >= 3`.
/// Never exposes prices.
class LicenseEntitlements {
  const LicenseEntitlements._({
    required this.payload,
    required this.byProduct,
    required this.addons,
    required this.offeringCodes,
  });

  final BillingTokenPayload payload;

  /// productId (or product_code) → resourceKey → summed quantity.
  final Map<String, Map<String, int>> byProduct;
  final Set<String> addons;
  final Set<String> offeringCodes;

  /// Build from a verified [BillingTokenPayload].
  ///
  /// When [catalog] is set, product / offering / add-on sets are intersected
  /// with the host catalog (fail-closed). Unknown JWT codes are dropped.
  factory LicenseEntitlements.fromPayload(
    BillingTokenPayload payload, {
    OfferingCatalog? catalog,
  }) {
    final byProduct = <String, Map<String, int>>{};
    final addons = <String>{};
    final offerings = <String>{};

    void addResource(String productKey, String resourceKey, int amount) {
      if (productKey.isEmpty || amount <= 0) return;
      final bucket = byProduct.putIfAbsent(productKey, () => <String, int>{});
      bucket[resourceKey] = (bucket[resourceKey] ?? 0) + amount;
    }

    final server = payload.entitlementsJson;
    var usedServerByProduct = false;
    if (server != null && payload.payloadVersion >= 3) {
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

      if (usedServerByProduct) continue;

      final q = s.quantity < 1 ? 1 : s.quantity;
      if (s.offerings.isNotEmpty) {
        for (final o in s.offerings) {
          final units = o.units < 1 ? 1 : o.units;
          final keys = <String>{
            if (o.productId.isNotEmpty) o.productId,
            if (o.productCode != null && o.productCode!.isNotEmpty)
              o.productCode!,
          };
          o.resources.forEach((key, value) {
            final n = parseInt(value);
            if (n != null && n > 0) {
              for (final productKey in keys) {
                addResource(productKey, key, n * units * q);
              }
            }
          });
        }
      } else if (s.maxDevices != null &&
          s.maxDevices! > 0 &&
          s.productId.isNotEmpty) {
        addResource(s.productId, 'max_devices', s.maxDevices! * q);
      }
    }

    if (catalog != null) {
      byProduct.removeWhere((k, _) => !catalog.knowsProduct(k));
      addons.removeWhere((a) => !catalog.knowsAddon(a));
      offerings.removeWhere((c) => !catalog.knowsOffering(c));
    }

    return LicenseEntitlements._(
      payload: payload,
      byProduct: Map.unmodifiable(
        byProduct.map(
          (k, v) => MapEntry(k, Map<String, int>.unmodifiable(v)),
        ),
      ),
      addons: Set.unmodifiable(addons),
      offeringCodes: Set.unmodifiable(offerings),
    );
  }

  /// All product ids/codes present in [byProduct].
  Set<String> get productIds => byProduct.keys.toSet();

  bool get hasAnyActiveSubscription =>
      payload.activeSubscriptions.any((s) => !s.isPeriodEnded);

  bool hasOffering(String offeringCode) =>
      offeringCodes.contains(offeringCode.trim());

  bool hasAddon(String addonCode) {
    final needle = addonCode.trim().toLowerCase();
    return addons.any((a) => a.toLowerCase() == needle);
  }

  bool hasProduct(String productId) => byProduct.containsKey(productId);

  bool hasPlan(String planId) => payload.activeSubscriptions
      .any((s) => s.planId == planId && !s.isPeriodEnded);

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
    for (final s in payload.activeSubscriptions) {
      if (s.isPeriodEnded) continue;
      if (soonest == null || s.validUntil.isBefore(soonest)) {
        soonest = s.validUntil;
      }
    }
    return soonest;
  }

  DateTime? expiryForProduct(String productId) {
    final id = productId.trim();
    DateTime? soonest;
    for (final s in payload.activeSubscriptions) {
      if (s.isPeriodEnded) continue;
      final hit = s.productId == id ||
          s.offerings.any(
            (o) => o.productId == id || o.productCode == id,
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
    for (final s in payload.activeSubscriptions) {
      if (s.isPeriodEnded) continue;
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
    for (final s in payload.activeSubscriptions) {
      if (s.isPeriodEnded) continue;
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
