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
  expiresAtUnix: number;
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
    expiresAtUnix: asInt(m.exp) ?? 4_102_444_800,
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
  /** productId → resourceKey → summed quantity */
  byProduct: Record<string, Record<string, number>>;
  maxDevices: number;
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

/** Feature-gate helpers: Product → Resources → Quantity (no monetary fields). */
export function licenseEntitlements(
  payload: LicensePayload,
  nowUnix: number = Math.floor(Date.now() / 1000),
  catalog?: OfferingCatalog,
): LicenseEntitlementsView {
  const byProduct: Record<string, Record<string, number>> = {};
  const addons = new Set<string>();
  const offerings = new Set<string>();

  const addResource = (productKey: string, resourceKey: string, amount: number) => {
    if (!productKey || amount <= 0) return;
    const bucket = byProduct[productKey] ?? {};
    bucket[resourceKey] = (bucket[resourceKey] ?? 0) + amount;
    byProduct[productKey] = bucket;
  };

  const server = payload.entitlementsJson;
  let usedServerByProduct = false;
  if (server && payload.payloadVersion >= 3) {
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
    if (usedServerByProduct) continue;

    const q = Math.max(1, s.quantity || 1);
    if (s.offerings.length > 0) {
      for (const o of s.offerings) {
        const units = Math.max(1, o.units || 1);
        const keys = [o.productId, o.productCode].filter(
          (k): k is string => typeof k === "string" && k.length > 0,
        );
        for (const [key, value] of Object.entries(o.resources)) {
          const n = asInt(value);
          if (n !== undefined && n > 0) {
            for (const productKey of keys) {
              addResource(productKey, key, n * units * q);
            }
          }
        }
      }
    } else if (s.maxDevices && s.maxDevices > 0 && s.productId) {
      addResource(s.productId, "max_devices", s.maxDevices * q);
    }
  }

  if (catalog) {
    for (const key of Object.keys(byProduct)) {
      if (!catalogKnowsProduct(catalog, key)) delete byProduct[key];
    }
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

  return {
    byProduct,
    maxDevices: resourceInt("max_devices"),
    hasAddon: (code) => {
      const needle = code.trim().toLowerCase();
      for (const a of addons) if (a.toLowerCase() === needle) return true;
      return false;
    },
    hasOffering: (code) => offerings.has(code.trim()),
    hasProduct: (productId) => Object.hasOwn(byProduct, productId),
    resourceForProduct: (productId, resourceKey, defaultValue = 0) =>
      byProduct[productId]?.[resourceKey] ?? defaultValue,
    resourceInt,
    maxDevicesForProduct: (productId, defaultValue = 0) =>
      byProduct[productId]?.max_devices ?? defaultValue,
    earliestExpiryUnix: () => {
      let soonest: number | undefined;
      for (const s of payload.subscriptions) {
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
