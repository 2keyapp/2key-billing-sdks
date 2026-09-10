import '../catalog/offering_catalog.dart';
import '../models/billing_subscription.dart';
import '../models/billing_token_payload.dart';

/// Plan-name hints when JWT only has numeric [BillingSubscription.planId].
///
/// Empty by default — host apps supply product-specific maps via
/// [BillingSdkConfig.addonPlanNameHints] or the [planNameHints] parameter.
const Map<String, List<String>> defaultAddonRefPlanNameHints = {};

/// Addon / offering codes on a seat (JWT may list codes this host does not gate).
Set<String> subscriptionFeatureCodes(BillingSubscription subscription) =>
    subscription.featureCodes;

/// Fail-closed host slice: JWT-only codes (linux in Office, pgp in Email) stay off.
/// Product-name match is not enough — linux seats are still product `Scomm`.
bool catalogAllowsSubscription(
  OfferingCatalog catalog,
  BillingSubscription subscription,
) =>
    subscription.isAllowedByCatalog(catalog);

/// True when [subscription] is an active seat for stable billing code [addonRef].
bool billingSubscriptionMatchesAddonRef(
  BillingSubscription subscription,
  String addonRef, {
  List<String> nameKeywords = const [],
  Map<String, List<String>> planNameHints = defaultAddonRefPlanNameHints,
  OfferingCatalog? catalog,
}) {
  if (!subscription.isActive) return false;

  final target = addonRef.trim().toLowerCase();
  if (target.isEmpty) return false;

  if (catalog != null &&
      !catalog.knowsAddon(target) &&
      !catalog.knowsOffering(target)) {
    return false;
  }

  if (subscription.planId.toLowerCase() == target) return true;
  if (subscription.matchesAddonRef(target)) return true;

  final keywords = <String>{
    ...nameKeywords.map((k) => k.toLowerCase()),
    ...?planNameHints[target],
  };

  if (keywords.isEmpty) return false;

  final productName = subscription.productName.toLowerCase();
  final planName = subscription.planName.toLowerCase();
  return keywords.any(
    (keyword) => productName.contains(keyword) || planName.contains(keyword),
  );
}

/// First matching active subscription renewal / valid-until date, if any.
DateTime? billingRenewalForAddonRef(
  BillingTokenPayload? payload,
  String addonRef, {
  List<String> nameKeywords = const [],
  Map<String, List<String>> planNameHints = defaultAddonRefPlanNameHints,
  OfferingCatalog? catalog,
}) {
  if (payload == null) return null;
  if (catalog != null &&
      !catalog.knowsAddon(addonRef) &&
      !catalog.knowsOffering(addonRef)) {
    return null;
  }
  final fromEntitlements =
      payload.entitlementsAgainst(catalog).expiryForAddon(addonRef);
  if (fromEntitlements != null) return fromEntitlements;
  for (final sub in payload.subscriptions) {
    if (!billingSubscriptionMatchesAddonRef(
      sub,
      addonRef,
      nameKeywords: nameKeywords,
      planNameHints: planNameHints,
      catalog: catalog,
    )) {
      continue;
    }
    return sub.validUntil;
  }
  return null;
}

bool billingHasActiveAddonRef(
  BillingTokenPayload? payload,
  String addonRef, {
  List<String> nameKeywords = const [],
  Map<String, List<String>> planNameHints = defaultAddonRefPlanNameHints,
  OfferingCatalog? catalog,
}) {
  if (payload == null) return false;
  if (catalog != null &&
      !catalog.knowsAddon(addonRef) &&
      !catalog.knowsOffering(addonRef)) {
    return false;
  }
  // Prefer Product→Resources entitlements (v3 addons list / offering resources).
  final entitlements = payload.entitlementsAgainst(catalog);
  if (entitlements.hasAddon(addonRef) && entitlements.hasAnyActiveSubscription) {
    return true;
  }
  return payload.subscriptions.any(
    (sub) => billingSubscriptionMatchesAddonRef(
      sub,
      addonRef,
      nameKeywords: nameKeywords,
      planNameHints: planNameHints,
      catalog: catalog,
    ),
  );
}
