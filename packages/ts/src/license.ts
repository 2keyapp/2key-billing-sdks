import { TwoKeyError } from "./errors.js";

function getKey(m: Record<string, unknown>, snake: string, camel: string): unknown {
  return m[snake] ?? m[camel];
}

function asString(v: unknown): string | undefined {
  return typeof v === "string" ? v : undefined;
}

function asInt(v: unknown): number | undefined {
  if (typeof v === "number" && Number.isFinite(v)) return Math.trunc(v);
  return undefined;
}

export type PayingParty = {
  id: string;
  identityProvider: string;
  identitySubject: string;
  billingEmail: string;
  organizationName?: string;
};

export type BillingSubscription = {
  subscriptionId: string;
  planId: string;
  productId: string;
  planName: string;
  productName: string;
  subscriptionStatus: string;
  validUntilUnix: number;
  validFromUnix?: number;
  billingInterval?: string;
  addonCode?: string;
  usingPartyIdentityProvider?: string;
  usingPartyIdentitySubject?: string;
  usingPartyEmail?: string;
  assignedUserPartyId?: string;
};

export type LicensePayload = {
  payloadVersion: number;
  expiresAtUnix: number;
  issuedAtUnix?: number;
  issuer?: string;
  audience?: string;
  payingParty: PayingParty;
  subscriptions: BillingSubscription[];
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
  return {
    subscriptionId: require("subscription_id", "subscriptionId"),
    planId: require("plan_id", "planId"),
    productId: require("product_id", "productId"),
    planName: require("plan_name", "planName"),
    productName: require("product_name", "productName"),
    subscriptionStatus: require("subscription_status", "subscriptionStatus"),
    validUntilUnix,
    validFromUnix: asInt(getKey(m, "valid_from", "validFrom")),
    billingInterval: asString(getKey(m, "billing_interval", "billingInterval")),
    addonCode: asString(getKey(m, "addon_code", "addonCode")),
    usingPartyIdentityProvider: asString(
      getKey(m, "using_party_identity_provider", "usingPartyIdentityProvider"),
    ),
    usingPartyIdentitySubject: asString(
      getKey(m, "using_party_identity_subject", "usingPartyIdentitySubject"),
    ),
    usingPartyEmail: asString(getKey(m, "using_party_email", "usingPartyEmail")),
    assignedUserPartyId: asString(getKey(m, "assigned_user_party_id", "assignedUserPartyId")),
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
  return {
    payloadVersion,
    expiresAtUnix: asInt(m.exp) ?? 4_102_444_800,
    issuedAtUnix: asInt(m.iat),
    issuer: asString(m.iss),
    audience: typeof m.aud === "string" ? m.aud : undefined,
    payingParty: parsePayingParty(getKey(m, "paying_party", "payingParty")),
    subscriptions: subscriptionsRaw.map(parseSubscription),
  };
}

export function isSubscriptionActive(status: string): boolean {
  const s = status.toLowerCase();
  return s === "active" || s === "trialing";
}
