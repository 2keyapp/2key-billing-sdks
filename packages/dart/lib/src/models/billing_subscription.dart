import 'jwt_payload_keys.dart';

/// Bound app_client device claim on a license subscription.
class LicenseDeviceClaim {
  const LicenseDeviceClaim({
    required this.ski,
    required this.deviceId,
    this.platform,
  });

  final String ski;
  final String deviceId;
  final String? platform;

  factory LicenseDeviceClaim.fromJson(Map<String, dynamic> json) {
    final ski = json['ski'];
    final deviceId = json['device_id'] ?? json['deviceId'];
    if (ski is! String || ski.isEmpty) {
      throw FormatException('devices[].ski required');
    }
    return LicenseDeviceClaim(
      ski: ski,
      deviceId: deviceId is String ? deviceId : '',
      platform: json['platform'] is String ? json['platform'] as String : null,
    );
  }
}

/// One offering grant inside a license subscription (payload_version >= 3).
class LicenseOfferingClaim {
  const LicenseOfferingClaim({
    required this.offeringId,
    required this.offeringCode,
    required this.productId,
    required this.units,
    required this.resources,
    this.productName,
    this.productCode,
  });

  final String offeringId;
  final String offeringCode;
  final String productId;
  final String? productName;
  final String? productCode;
  final int units;
  final Map<String, Object?> resources;

  factory LicenseOfferingClaim.fromJson(Map<String, dynamic> json) {
    final offeringId = getKey(json, 'offering_id', 'offeringId');
    final offeringCode = getKey(json, 'offering_code', 'offeringCode');
    final productId = getKey(json, 'product_id', 'productId');
    if (offeringId is! String || offeringId.isEmpty) {
      throw FormatException('offerings[].offering_id required');
    }
    if (offeringCode is! String || offeringCode.isEmpty) {
      throw FormatException('offerings[].offering_code required');
    }
    if (productId is! String || productId.isEmpty) {
      throw FormatException('offerings[].product_id required');
    }
    final unitsRaw = getKey(json, 'units', 'units');
    final units = parseInt(unitsRaw) ?? 1;
    final resourcesRaw = json['resources'];
    final resources = <String, Object?>{};
    if (resourcesRaw is Map) {
      resourcesRaw.forEach((k, v) {
        if (k is String) resources[k] = v;
      });
    }
    final productName = getKey(json, 'product_name', 'productName');
    final productCode = getKey(json, 'product_code', 'productCode');
    return LicenseOfferingClaim(
      offeringId: offeringId,
      offeringCode: offeringCode,
      productId: productId,
      productName: productName is String ? productName : null,
      productCode: productCode is String ? productCode : null,
      units: units < 1 ? 1 : units,
      resources: resources,
    );
  }

  String? get addonCode {
    final a = resources['addon_code'] ?? resources['addonCode'];
    return a is String && a.isNotEmpty ? a : null;
  }

  int? get maxDevices {
    final v = resources['max_devices'] ?? resources['maxDevices'];
    return parseInt(v);
  }
}

/// A single subscription in the billing token payload.
/// Each element of top-level `subscriptions[]`.
class BillingSubscription {
  const BillingSubscription({
    required this.subscriptionId,
    required this.planId,
    required this.planName,
    required this.subscriptionStatus,
    required this.validUntil,
    this.productId = '',
    this.productName = '',
    this.quantity = 1,
    this.validFrom,
    this.billingInterval,
    this.addonCode,
    this.memberId,
    this.maxDevices,
    this.offerings = const [],
    this.devices = const [],
    this.usingPartyIdentityProvider,
    this.usingPartyIdentitySubject,
    this.usingPartyEmail,
    this.assignedUserPartyId,
  });

  final String subscriptionId;
  final String planId;
  final String productId;
  final String planName;
  final String productName;
  final int quantity;
  final String subscriptionStatus;
  final DateTime validUntil;
  final DateTime? validFrom;
  final String? billingInterval;
  final String? addonCode;
  final String? memberId;
  final int? maxDevices;
  final List<LicenseOfferingClaim> offerings;
  final List<LicenseDeviceClaim> devices;
  final String? usingPartyIdentityProvider;
  final String? usingPartyIdentitySubject;
  final String? usingPartyEmail;
  final String? assignedUserPartyId;

  /// Parses from subscription object in JWT payload. Throws [FormatException] if invalid.
  factory BillingSubscription.fromJson(Map<String, dynamic> json) {
    final subscriptionId = getKey(json, 'subscription_id', 'subscriptionId');
    final planId = getKey(json, 'plan_id', 'planId');
    final planName = getKey(json, 'plan_name', 'planName');
    final status = getKey(json, 'subscription_status', 'subscriptionStatus');
    final validUntil = getKey(json, 'valid_until', 'validUntil');
    if (subscriptionId is! String) {
      throw FormatException('subscriptions[].subscription_id required.');
    }
    if (planId is! String) {
      throw FormatException('subscriptions[].plan_id required.');
    }
    if (planName is! String) {
      throw FormatException('subscriptions[].plan_name required.');
    }
    if (status is! String) {
      throw FormatException('subscriptions[].subscription_status required.');
    }
    final validUntilInt = parseInt(validUntil);
    if (validUntilInt == null) {
      throw FormatException(
        'subscriptions[].valid_until required (Unix timestamp).',
      );
    }

    final offeringsRaw = json['offerings'];
    final offerings = <LicenseOfferingClaim>[];
    if (offeringsRaw is List) {
      for (final item in offeringsRaw) {
        if (item is Map<String, dynamic>) {
          offerings.add(LicenseOfferingClaim.fromJson(item));
        } else if (item is Map) {
          offerings.add(
            LicenseOfferingClaim.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    // v2 required product_*; v3 may omit and supply via offerings[].
    var productId = getKey(json, 'product_id', 'productId');
    var productName = getKey(json, 'product_name', 'productName');
    if (productId is! String || productId.isEmpty) {
      productId = offerings.isNotEmpty ? offerings.first.productId : '';
    }
    if (productName is! String || productName.isEmpty) {
      productName = offerings.isNotEmpty
          ? (offerings.first.productName ?? '')
          : '';
    }
    if (offerings.isEmpty && (productId is! String || productId.isEmpty)) {
      throw FormatException('subscriptions[].product_id required.');
    }
    if (offerings.isEmpty && (productName is! String || productName.isEmpty)) {
      throw FormatException('subscriptions[].product_name required.');
    }

    final validFromRaw = getKey(json, 'valid_from', 'validFrom');
    final validFromInt = parseInt(validFromRaw);
    final billingIntervalRaw =
        getKey(json, 'billing_interval', 'billingInterval');
    final assigned = getKey(
      json,
      'assigned_user_party_id',
      'assignedUserPartyId',
    );
    final addon = getKey(json, 'addon_code', 'addonCode');
    final memberId = getKey(json, 'member_id', 'memberId');
    final maxDevicesRaw = getKey(json, 'max_devices', 'maxDevices');
    final quantityRaw = getKey(json, 'quantity', 'quantity');
    final quantity = parseInt(quantityRaw) ?? 1;
    final usingProvider = getKey(
      json,
      'using_party_identity_provider',
      'usingPartyIdentityProvider',
    );
    final usingSubject = getKey(
      json,
      'using_party_identity_subject',
      'usingPartyIdentitySubject',
    );
    final usingEmail = getKey(json, 'using_party_email', 'usingPartyEmail');
    final devicesRaw = json['devices'];
    final devices = <LicenseDeviceClaim>[];
    if (devicesRaw is List) {
      for (final item in devicesRaw) {
        if (item is Map<String, dynamic>) {
          devices.add(LicenseDeviceClaim.fromJson(item));
        } else if (item is Map) {
          devices.add(
            LicenseDeviceClaim.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    String? addonCode = addon is String && addon.isNotEmpty ? addon : null;
    if (addonCode == null) {
      for (final o in offerings) {
        final c = o.addonCode;
        if (c != null) {
          addonCode = c;
          break;
        }
      }
    }

    return BillingSubscription(
      subscriptionId: subscriptionId,
      planId: planId,
      productId: productId is String ? productId : '',
      planName: planName,
      productName: productName is String ? productName : '',
      quantity: quantity < 1 ? 1 : quantity,
      subscriptionStatus: status,
      validUntil: dateTimeFromUnixSeconds(validUntilInt),
      validFrom: validFromInt != null
          ? dateTimeFromUnixSeconds(validFromInt)
          : null,
      billingInterval: billingIntervalRaw is String &&
              billingIntervalRaw.trim().isNotEmpty
          ? billingIntervalRaw.trim()
          : null,
      addonCode: addonCode,
      memberId: memberId is String && memberId.isNotEmpty ? memberId : null,
      maxDevices: parseInt(maxDevicesRaw),
      offerings: offerings,
      devices: devices,
      usingPartyIdentityProvider:
          usingProvider is String && usingProvider.isNotEmpty
              ? usingProvider
              : null,
      usingPartyIdentitySubject:
          usingSubject is String && usingSubject.isNotEmpty ? usingSubject : null,
      usingPartyEmail:
          usingEmail is String && usingEmail.isNotEmpty ? usingEmail : null,
      assignedUserPartyId: assigned is String && assigned.isNotEmpty
          ? assigned
          : null,
    );
  }

  /// Whether this subscription is currently active (e.g. active, trialing).
  bool get isActive =>
      subscriptionStatus.toLowerCase() == 'active' ||
      subscriptionStatus.toLowerCase() == 'trialing';

  /// Whether [addonRef] matches server [addonCode] metadata.
  bool matchesAddonRef(String addonRef) {
    final code = addonCode;
    if (code != null &&
        code.isNotEmpty &&
        code.toLowerCase() == addonRef.trim().toLowerCase()) {
      return true;
    }
    final needle = addonRef.trim().toLowerCase();
    return offerings.any((o) => o.addonCode?.toLowerCase() == needle);
  }

  /// Whether the validity period has ended (now > valid_until).
  bool get isPeriodEnded => DateTime.now().isAfter(validUntil);

  /// True when [localSki] is listed, or when no devices are bound yet.
  bool allowsDevice(String localSki) {
    if (devices.isEmpty) return true;
    return devices.any((d) => d.ski == localSki);
  }
}
