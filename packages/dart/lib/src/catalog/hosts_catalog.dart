import '../catalog/offering_catalog.dart';

/// One host slice from seed-repo `hosts.json`.
class HostCatalogSlice {
  const HostCatalogSlice({
    required this.offeringCodes,
    required this.addonCodes,
  });

  final Set<String> offeringCodes;
  final Set<String> addonCodes;

  factory HostCatalogSlice.fromJson(Map<String, dynamic> json, String hostKey) {
    return HostCatalogSlice(
      offeringCodes: _stringSet(json['offeringCodes'], 'hosts.$hostKey.offeringCodes'),
      addonCodes: _stringSet(json['addonCodes'], 'hosts.$hostKey.addonCodes'),
    );
  }
}

/// Parsed seed-repo `hosts.json`. Apps bake this file at build time.
class HostsCatalog {
  const HostsCatalog({
    required this.productNames,
    required this.hosts,
  });

  final Set<String> productNames;
  final Map<String, HostCatalogSlice> hosts;

  /// Parse `hosts.json`. Accepts legacy `productIds` when `productNames` is absent.
  factory HostsCatalog.fromJson(Map<String, dynamic> json) {
    final hostsRaw = json['hosts'];
    if (hostsRaw is! Map) {
      throw FormatException('hosts.json hosts must be an object');
    }
    final hosts = <String, HostCatalogSlice>{};
    hostsRaw.forEach((key, value) {
      if (key is! String || key.isEmpty) return;
      if (value is! Map) {
        throw FormatException('hosts.$key must be an object');
      }
      hosts[key] = HostCatalogSlice.fromJson(
        Map<String, dynamic>.from(value),
        key,
      );
    });

    final namesRaw = json['productNames'] ?? json['productIds'];
    final productNames = namesRaw == null
        ? <String>{}
        : _stringSet(namesRaw, 'productNames');

    return HostsCatalog(productNames: productNames, hosts: Map.unmodifiable(hosts));
  }

  /// Offering catalog for one baked host key (`office`, `scommDesktop`, …).
  OfferingCatalog forHost(String hostKey) {
    final slice = hosts[hostKey];
    if (slice == null) {
      throw ArgumentError.value(hostKey, 'hostKey', 'unknown host catalog');
    }
    return OfferingCatalog(
      productNames: productNames,
      offeringCodes: slice.offeringCodes,
      addonCodes: slice.addonCodes,
    );
  }
}

Set<String> _stringSet(Object? raw, String label) {
  if (raw is! List) {
    throw FormatException('$label must be an array of strings');
  }
  final out = <String>{};
  for (final item in raw) {
    if (item is! String || item.trim().isEmpty) {
      throw FormatException('$label must be an array of strings');
    }
    out.add(item);
  }
  return out;
}
