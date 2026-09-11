import { TwoKeyError } from "./errors.js";
import {
  catalogKnowsAddon,
  catalogKnowsOffering,
  catalogKnowsProduct,
  type OfferingCatalog,
} from "./offering-catalog.js";

function getKey(m: Record<string, unknown>, snake: string, camel: string): unknown {
  return m[snake] ?? m[camel];
}

function asString(v: unknown): string | undefined {
  return typeof v === "string" ? v : undefined;
}

function asInt(v: unknown): number | undefined {
  if (typeof v === "number" && Number.isFinite(v)) return Math.trunc(v);
  if (typeof v === "string" && v.trim() !== "") {
    const n = Number(v);
    if (Number.isFinite(n)) return Math.trunc(n);
  }
  return undefined;
}

export type PayingParty = {
  id: string;
  identityProvider: string;
  identitySubject: string;
  billingEmail: string;
  organizationName?: string;
};

export type LicenseDeviceClaim = {
  ski: string;
  deviceId: string;
  platform?: string;
  friendlyName?: string;
};

export type LicenseOfferingClaim = {
  offeringId: string;
  offeringCode: string;
  productId: string;
  productName?: string;
  productCode?: string;
  units: number;
  resources: Record<string, unknown>;
};

/** Catalog product name, then code, then serial id — one key so SUM does not double-count. */
function productGroupKey(offering: LicenseOfferingClaim): string {
  const name = offering.productName?.trim();
  if (name) return name;
  const code = offering.productCode?.trim();
  if (code) return code;
  return offering.productId.trim();
}

const NON_RESOURCE_KEYS = new Set([
  "addon_code",
  "addonCode",
  "surfaces",
  "platforms",
  "usage_grants",
  "usageGrants",
]);

function featureGroupKey(offering: LicenseOfferingClaim): string {
  const addon = offering.resources.addon_code ?? offering.resources.addonCode;
  if (typeof addon === "string" && addon.trim() !== "") return addon.trim();
  return offering.offeringCode.trim();
}

export type NormalizedProducts = Record<string, Record<string, Record<string, number>>>;

export type BillingSubscription = {
  subscriptionId: string;
  planId: string;
  productId: string;
  planName: string;
  productName: string;
  quantity: number;
  subscriptionStatus: string;
  validUntilUnix: number;
  validFromUnix?: number;
  billingInterval?: string;
  addonCode?: string;
  maxDevices?: number;
  offerings: LicenseOfferingClaim[];
  usingPartyIdentityProvider?: string;
  usingPartyIdentitySubject?: string;
  usingPartyEmail?: string;
  assignedUserPartyId?: string;
  devices: LicenseDeviceClaim[];
};

export type LicensePayload = {
  payloadVersion: number;
  /** Optional JWT `exp` if present. License validity is subscription `valid_until`. */
  expiresAtUnix?: number;
  issuedAtUnix?: number;
  issuer?: string;
  audience?: string;
  payingParty: PayingParty;
  subscriptions: BillingSubscription[];
  /** Raw server entitlements when payload_version >= 3. */
  entitlementsJson?: Record<string, unknown>;
};

function parsePayingParty(raw: unknown): PayingParty {
  if (!raw || typeof raw !== "object") {
    throw new TwoKeyError("license_malformed", "paying_party object required");
  }
  const m = raw as Record<string, unknown>;
  const id = asString(getKey(m, "id", "id"));
  const billingEmail = asString(getKey(m, "billing_email", "billingEmail"));
  if (!id) throw new TwoKeyError("license_malformed", "paying_party.id required");
  if (billingEmail === undefined) {
    throw new TwoKeyError("license_malformed", "paying_party.billing_email required");
  }
  let identityProvider = asString(getKey(m, "identity_provider", "identityProvider"));
  let identitySubject = asString(getKey(m, "identity_subject", "identitySubject"));
  const sso = asString(getKey(m, "sso_id", "ssoId"));
  if ((!identityProvider || !identitySubject) && sso) {
    identityProvider = identityProvider || "legacy";
    identitySubject = identitySubject || sso;
  }
  if (!identityProvider || !identitySubject) {
    throw new TwoKeyError(
      "license_malformed",
      "paying_party: identity_provider and identity_subject required (or legacy sso_id)",
    );
  }
  return {
    id,
    identityProvider,
    identitySubject,
    billingEmail,
    organizationName: asString(getKey(m, "organization_name", "organizationName")),
  };
}

function parseOffering(raw: unknown, index: number): LicenseOfferingClaim {
  if (!raw || typeof raw !== "object") {
    throw new TwoKeyError("license_malformed", `offerings[${index}] must be an object`);
  }
  const m = raw as Record<string, unknown>;
  const offeringId = asString(getKey(m, "offering_id", "offeringId"));
  const offeringCode = asString(getKey(m, "offering_code", "offeringCode"));
  const productId = asString(getKey(m, "product_id", "productId"));
  if (!offeringId) {
    throw new TwoKeyError("license_malformed", "offerings[].offering_id required");
  }
  if (!offeringCode) {
    throw new TwoKeyError("license_malformed", "offerings[].offering_code required");
  }
  if (!productId) {
    throw new TwoKeyError("license_malformed", "offerings[].product_id required");
  }
  const resourcesRaw = m.resources;
  const resources =
    resourcesRaw && typeof resourcesRaw === "object" && !Array.isArray(resourcesRaw)
      ? (resourcesRaw as Record<string, unknown>)
      : {};
  return {
    offeringId,
    offeringCode,
    productId,
    productName: asString(getKey(m, "product_name", "productName")),
    productCode: asString(getKey(m, "product_code", "productCode")),
    units: Math.max(1, asInt(getKey(m, "units", "units")) ?? 1),
    resources,
  };
}

function parseDeviceClaim(raw: unknown): LicenseDeviceClaim | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const m = raw as Record<string, unknown>;
  const ski = asString(m.ski);
  if (!ski) return undefined;
  return {
    ski,
    deviceId: asString(getKey(m, "device_id", "deviceId")) ?? "",
    platform: asString(m.platform),
    friendlyName: asString(getKey(m, "friendly_name", "friendlyName")),
  };
}

function parseSubscription(raw: unknown, index: number): BillingSubscription {
  if (!raw || typeof raw !== "object") {
    throw new TwoKeyError("license_malformed", `subscriptions[${index}] must be an object`);
  }
  const m = raw as Record<string, unknown>;
  const require = (snake: string, camel: string) => {
    const v = asString(getKey(m, snake, camel));
    if (!v) {
      throw new TwoKeyError("license_malformed", `subscriptions[].${snake} required`);
    }
    return v;
  };
  const validUntilUnix = asInt(getKey(m, "valid_until", "validUntil"));
  if (validUntilUnix === undefined) {
    throw new TwoKeyError(
      "license_malformed",
      "subscriptions[].valid_until required (Unix timestamp)",
    );
  }

  const offeringsRaw = m.offerings;
  const offerings: LicenseOfferingClaim[] = [];
  if (Array.isArray(offeringsRaw)) {
    offeringsRaw.forEach((item, i) => offerings.push(parseOffering(item, i)));
  }

  let productId = asString(getKey(m, "product_id", "productId")) ?? "";
  let productName = asString(getKey(m, "product_name", "productName")) ?? "";
  if (!productId && offerings[0]) productId = offerings[0].productId;
  if (!productName && offerings[0]?.productName) productName = offerings[0].productName;
  if (!productId) {
    throw new TwoKeyError("license_malformed", "subscriptions[].product_id required");
  }
  if (!productName && offerings.length === 0) {
    throw new TwoKeyError("license_malformed", "subscriptions[].product_name required");
  }

  let addonCode = asString(getKey(m, "addon_code", "addonCode"));
  if (!addonCode) {
    for (const o of offerings) {
      const a = o.resources.addon_code ?? o.resources.addonCode;
      if (typeof a === "string" && a) {
        addonCode = a;
        break;
      }
    }
  }

  return {
    subscriptionId: require("subscription_id", "subscriptionId"),
    planId: require("plan_id", "planId"),
    productId,
    planName: require("plan_name", "planName"),
    productName: productName || productId,
    quantity: Math.max(1, asInt(getKey(m, "quantity", "quantity")) ?? 1),
    subscriptionStatus: require("subscription_status", "subscriptionStatus"),
    validUntilUnix,
    validFromUnix: asInt(getKey(m, "valid_from", "validFrom")),
    billingInterval: asString(getKey(m, "billing_interval", "billingInterval")),
    addonCode,
    maxDevices: asInt(getKey(m, "max_devices", "maxDevices")),
    offerings,
    usingPartyIdentityProvider: asString(
      getKey(m, "using_party_identity_provider", "usingPartyIdentityProvider"),
    ),
    usingPartyIdentitySubject: asString(
      getKey(m, "using_party_identity_subject", "usingPartyIdentitySubject"),
    ),
    usingPartyEmail: asString(getKey(m, "using_party_email", "usingPartyEmail")),
    assignedUserPartyId: asString(getKey(m, "assigned_user_party_id", "assignedUserPartyId")),
    devices: Array.isArray(m.devices)
      ? m.devices.map(parseDeviceClaim).filter((d): d is LicenseDeviceClaim => !!d)
      : [],
  };
}

/** Parse license JWT claims object (after signature verify). */
export function parseLicenseClaims(claims: unknown): LicensePayload {
  if (!claims || typeof claims !== "object") {
    throw new TwoKeyError("license_malformed", "Expected JSON object payload");
  }
  const m = claims as Record<string, unknown>;
  const payloadVersion = asInt(getKey(m, "payload_version", "payloadVersion"));
  if (payloadVersion === undefined) {
    throw new TwoKeyError("license_malformed", "payload_version (number) required");
  }
  const subscriptionsRaw = m.subscriptions;
  if (!Array.isArray(subscriptionsRaw)) {
    throw new TwoKeyError("license_malformed", "subscriptions array required");
  }
  const entitlementsRaw = m.entitlements;
  const entitlementsJson =
    entitlementsRaw && typeof entitlementsRaw === "object" && !Array.isArray(entitlementsRaw)
      ? (entitlementsRaw as Record<string, unknown>)
      : undefined;
  return {
    payloadVersion,
    expiresAtUnix: asInt(m.exp),
    issuedAtUnix: asInt(m.iat),
    issuer: asString(m.iss),
    audience: typeof m.aud === "string" ? m.aud : undefined,
    payingParty: parsePayingParty(getKey(m, "paying_party", "payingParty")),
    subscriptions: subscriptionsRaw.map(parseSubscription),
    entitlementsJson,
  };
}

export function isSubscriptionActive(status: string): boolean {
  const s = status.toLowerCase();
  return s === "active" || s === "trialing";
}

export type LicenseEntitlementsView = {
  /** product name → resourceKey → summed quantity */
  byProduct: Record<string, Record<string, number>>;
  maxDevices: number;
  /** Active add-on codes (no prices). Parity with Dart `LicenseEntitlements.addons`. */
  addonCodes: string[];
  /** Active offering codes (no prices). Parity with Dart `LicenseEntitlements.offeringCodes`. */
  offeringCodes: string[];
  /**
   * Seats this host may show (`catalog ∩ JWT`). When no catalog is configured,
   * this is the raw JWT list. Device bind still uses `payload.subscriptions`.
   */
  subscriptions: BillingSubscription[];
  /**
   * Product → feature → `{ count, …resources }`. No prices, no plan rows.
   * Apps should query this on start. `count` is COUNT(*) of granted units.
   */
  normalizedJson: () => { products: NormalizedProducts };
  hasAddon: (code: string) => boolean;
  hasOffering: (code: string) => boolean;
  hasProduct: (productId: string) => boolean;
  resourceForProduct: (productId: string, resourceKey: string, defaultValue?: number) => number;
  resourceInt: (key: string, defaultValue?: number) => number;
  maxDevicesForProduct: (productId: string, defaultValue?: number) => number;
  earliestExpiryUnix: () => number | undefined;
  /** True when [localSki] is listed, or no subscription has bound devices yet. */
  allowsDevice: (localSki: string) => boolean;
};

/** True when any subscription lists [ski] in `devices`. */
export function licenseListsSki(payload: LicensePayload | null | undefined, ski: string): boolean {
  if (!payload) return false;
  const needle = ski.trim();
  if (!needle) return false;
  for (const s of payload.subscriptions) {
    if (s.devices.some((d) => d.ski === needle)) return true;
  }
  return false;
}

/** Addon / offering codes on a seat (JWT may list codes this host does not gate). */
export function subscriptionFeatureCodes(sub: BillingSubscription): string[] {
  const codes: string[] = [];
  const push = (value: string | undefined) => {
    const n = value?.trim();
    if (n && !codes.includes(n)) codes.push(n);
  };
  push(sub.addonCode);
  for (const offering of sub.offerings) {
    push(offering.offeringCode);
    const addon = offering.resources.addon_code ?? offering.resources.addonCode;
    if (typeof addon === "string") push(addon);
  }
  return codes;
}

/**
 * Fail-closed host slice: a seat is visible only when at least one of its
 * feature codes is in this binary’s catalog. JWT-only codes stay off.
 * Sharing a product name with the catalog is not enough when the seat
 * also lists add-on / offering codes this host does not gate.
 */
export function catalogAllowsSubscription(
  catalog: OfferingCatalog,
  sub: BillingSubscription,
): boolean {
  const codes = subscriptionFeatureCodes(sub);
  if (codes.length === 0) {
    return (
      catalogKnowsProduct(catalog, sub.productId) ||
      catalogKnowsProduct(catalog, sub.productName)
    );
  }
  return codes.some(
    (code) => catalogKnowsAddon(catalog, code) || catalogKnowsOffering(catalog, code),
  );
}

function subscriptionProductAliases(sub: BillingSubscription): string[] {
  const aliases: string[] = [];
  const push = (value: string | undefined) => {
    const n = value?.trim();
    if (n && !aliases.includes(n)) aliases.push(n);
  };
  push(sub.productId);
  push(sub.productName);
  for (const offering of sub.offerings) {
    push(offering.productId);
    push(offering.productCode);
    push(offering.productName);
  }
  return aliases;
}

/**
 * Keep catalog-known product keys only. Remap JWT serial `product_id` buckets
 * onto `product_name` when the baked catalog lists names (hosts.json).
 * Never duplicate the same bucket under two keys — `resourceInt` would double.
 */
function applyCatalogToByProduct(
  byProduct: Record<string, Record<string, number>>,
  payload: LicensePayload,
  catalog: OfferingCatalog,
): Record<string, Record<string, number>> {
  const next: Record<string, Record<string, number>> = {};

  for (const [key, bucket] of Object.entries(byProduct)) {
    if (catalogKnowsProduct(catalog, key)) next[key] = bucket;
  }

  for (const sub of payload.subscriptions) {
    const aliases = subscriptionProductAliases(sub);
    const sourceKey = aliases.find((alias) => byProduct[alias] != null);
    if (sourceKey == null) continue;
    const bucket = byProduct[sourceKey];
    if (bucket == null) continue;
    for (const alias of aliases) {
      if (!catalogKnowsProduct(catalog, alias)) continue;
      if (next[alias] == null) next[alias] = bucket;
    }
  }

  return next;
}

function applyCatalogToProducts(
  products: NormalizedProducts,
  payload: LicensePayload,
  catalog: OfferingCatalog,
): NormalizedProducts {
  const knowsFeature = (code: string) =>
    catalogKnowsAddon(catalog, code) || catalogKnowsOffering(catalog, code);

  const filterFeatures = (features: Record<string, Record<string, number>>) => {
    const next: Record<string, Record<string, number>> = {};
    for (const [code, bucket] of Object.entries(features)) {
      if (knowsFeature(code)) next[code] = bucket;
    }
    return next;
  };

  const next: NormalizedProducts = {};
  for (const [key, features] of Object.entries(products)) {
    if (!catalogKnowsProduct(catalog, key)) continue;
    const filtered = filterFeatures(features);
    if (Object.keys(filtered).length > 0) next[key] = filtered;
  }
  for (const sub of payload.subscriptions) {
    const aliases = subscriptionProductAliases(sub);
    const sourceKey = aliases.find((alias) => products[alias] != null);
    if (sourceKey == null) continue;
    const filtered = filterFeatures(products[sourceKey] ?? {});
    if (Object.keys(filtered).length === 0) continue;
    for (const alias of aliases) {
      if (!catalogKnowsProduct(catalog, alias)) continue;
      if (next[alias] == null) next[alias] = filtered;
    }
  }
  return next;
}

/** Feature-gate helpers: Product → Feature → `{ count, …resources }` (no money). */
export function licenseEntitlements(
  payload: LicensePayload,
  nowUnix: number = Math.floor(Date.now() / 1000),
  catalog?: OfferingCatalog,
): LicenseEntitlementsView {
  let products: NormalizedProducts = {};
  let byProduct: Record<string, Record<string, number>> = {};
  const addons = new Set<string>();
  const offerings = new Set<string>();

  const addResource = (productKey: string, resourceKey: string, amount: number) => {
    if (!productKey || amount <= 0) return;
    if (NON_RESOURCE_KEYS.has(resourceKey) || resourceKey === "count") return;
    const bucket = byProduct[productKey] ?? {};
    bucket[resourceKey] = (bucket[resourceKey] ?? 0) + amount;
    byProduct[productKey] = bucket;
  };

  const addFeature = (
    productKey: string,
    featureKey: string,
    resourceKey: string,
    amount: number,
  ) => {
    if (!productKey || !featureKey || amount <= 0) return;
    if (resourceKey !== "count" && NON_RESOURCE_KEYS.has(resourceKey)) return;
    const features = products[productKey] ?? {};
    const bucket = features[featureKey] ?? {};
    bucket[resourceKey] = (bucket[resourceKey] ?? 0) + amount;
    features[featureKey] = bucket;
    products[productKey] = features;
  };

  const server = payload.entitlementsJson;
  let usedServerByProduct = false;
  let usedServerProducts = false;
  if (server && payload.payloadVersion >= 3) {
    const rawProducts = server.products;
    if (rawProducts && typeof rawProducts === "object" && !Array.isArray(rawProducts)) {
      for (const [productKey, features] of Object.entries(
        rawProducts as Record<string, unknown>,
      )) {
        if (!features || typeof features !== "object" || Array.isArray(features)) continue;
        const featureEntries = Object.entries(features as Record<string, unknown>);
        const nested = featureEntries.some(
          ([, bucket]) => bucket && typeof bucket === "object" && !Array.isArray(bucket),
        );
        if (!nested) continue;
        usedServerProducts = true;
        for (const [featureKey, bucket] of featureEntries) {
          if (!bucket || typeof bucket !== "object" || Array.isArray(bucket)) continue;
          for (const [resourceKey, value] of Object.entries(bucket as Record<string, unknown>)) {
            const n = asInt(value);
            if (n !== undefined && n > 0) addFeature(productKey, featureKey, resourceKey, n);
          }
        }
      }
    }
    const rawByProduct = server.by_product ?? server.byProduct;
    if (rawByProduct && typeof rawByProduct === "object" && !Array.isArray(rawByProduct)) {
      usedServerByProduct = true;
      for (const [productKey, resources] of Object.entries(
        rawByProduct as Record<string, unknown>,
      )) {
        if (!resources || typeof resources !== "object" || Array.isArray(resources)) continue;
        for (const [resourceKey, value] of Object.entries(resources as Record<string, unknown>)) {
          const n = asInt(value);
          if (n !== undefined && n > 0) addResource(productKey, resourceKey, n);
        }
      }
    }
    if (Array.isArray(server.addons)) {
      for (const a of server.addons) if (typeof a === "string" && a) addons.add(a);
    }
    const byOffering = server.by_offering_code ?? server.byOfferingCode;
    if (byOffering && typeof byOffering === "object") {
      for (const [code, res] of Object.entries(byOffering as Record<string, unknown>)) {
        offerings.add(code);
        if (res && typeof res === "object") {
          const r = res as Record<string, unknown>;
          const a = r.addon_code ?? r.addonCode;
          if (typeof a === "string" && a) addons.add(a);
        }
      }
    }
  }

  for (const s of payload.subscriptions) {
    if (!isSubscriptionActive(s.subscriptionStatus) || s.validUntilUnix <= nowUnix) continue;
    if (s.addonCode) addons.add(s.addonCode);
    for (const o of s.offerings) {
      offerings.add(o.offeringCode);
      const a = o.resources.addon_code ?? o.resources.addonCode;
      if (typeof a === "string" && a) addons.add(a);
    }

    const q = Math.max(1, s.quantity || 1);
    if (s.offerings.length > 0) {
      for (const o of s.offerings) {
        const units = Math.max(1, o.units || 1);
        const multiplier = units * q;
        const productKey = productGroupKey(o);
        const feat = featureGroupKey(o);
        if (!productKey) continue;
        if (!usedServerProducts) addFeature(productKey, feat, "count", multiplier);
        for (const [key, value] of Object.entries(o.resources)) {
          const n = asInt(value);
          if (n !== undefined && n > 0) {
            if (!usedServerByProduct) addResource(productKey, key, n * multiplier);
            if (!usedServerProducts) addFeature(productKey, feat, key, n * multiplier);
          }
        }
      }
    } else if (s.productName || s.productId) {
      const productKey = s.productName || s.productId;
      const feat = s.addonCode?.trim() || productKey;
      if (!usedServerProducts) addFeature(productKey, feat, "count", q);
      if (s.maxDevices && s.maxDevices > 0) {
        if (!usedServerByProduct) addResource(productKey, "max_devices", s.maxDevices * q);
        if (!usedServerProducts) {
          addFeature(productKey, feat, "max_devices", s.maxDevices * q);
        }
      }
    }
  }

  if (catalog) {
    byProduct = applyCatalogToByProduct(byProduct, payload, catalog);
    products = applyCatalogToProducts(products, payload, catalog);
    for (const a of [...addons]) {
      if (!catalogKnowsAddon(catalog, a)) addons.delete(a);
    }
    for (const o of [...offerings]) {
      if (!catalogKnowsOffering(catalog, o)) offerings.delete(o);
    }
  }

  const resourceInt = (key: string, defaultValue = 0) => {
    let total = 0;
    let found = false;
    for (const resources of Object.values(byProduct)) {
      const n = resources[key];
      if (typeof n === "number") {
        found = true;
        total += n;
      }
    }
    return found ? total : defaultValue;
  };

  const hostSubscriptions = catalog
    ? payload.subscriptions.filter((sub) => catalogAllowsSubscription(catalog, sub))
    : payload.subscriptions;

  return {
    byProduct,
    maxDevices: resourceInt("max_devices"),
    addonCodes: [...addons].sort(),
    offeringCodes: [...offerings].sort(),
    subscriptions: hostSubscriptions,
    normalizedJson: () => ({ products }),
    hasAddon: (code) => {
      const needle = code.trim().toLowerCase();
      for (const a of addons) if (a.toLowerCase() === needle) return true;
      return false;
    },
    hasOffering: (code) => offerings.has(code.trim()),
    hasProduct: (productId) =>
      Object.hasOwn(products, productId) || Object.hasOwn(byProduct, productId),
    resourceForProduct: (productId, resourceKey, defaultValue = 0) =>
      byProduct[productId]?.[resourceKey] ?? defaultValue,
    resourceInt,
    maxDevicesForProduct: (productId, defaultValue = 0) =>
      byProduct[productId]?.max_devices ?? defaultValue,
    earliestExpiryUnix: () => {
      let soonest: number | undefined;
      for (const s of hostSubscriptions) {
        if (!isSubscriptionActive(s.subscriptionStatus) || s.validUntilUnix <= nowUnix) continue;
        if (soonest === undefined || s.validUntilUnix < soonest) soonest = s.validUntilUnix;
      }
      return soonest;
    },
    allowsDevice: (localSki) => {
      const needle = localSki.trim();
      let sawBound = false;
      for (const s of payload.subscriptions) {
        if (!isSubscriptionActive(s.subscriptionStatus) || s.validUntilUnix <= nowUnix) continue;
        if (s.devices.length === 0) continue;
        sawBound = true;
        if (s.devices.some((d) => d.ski === needle)) return true;
      }
      return !sawBound;
    },
  };
}
