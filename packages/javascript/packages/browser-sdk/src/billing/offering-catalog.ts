/**
 * Host-declared product / offering / add-on codes this binary knows how to gate.
 *
 * Runtime gates are `static catalog ∩ verified license JWT`.
 * Unknown JWT codes are ignored; catalog codes missing from the JWT fail closed.
 *
 * Bake the tenant’s `hosts.json` at build time and pass
 * `catalogForHost(hosts, hostKey)` into `createBillingClient`. Product
 * identity is a catalog **name** (`productNames`), not a Postgres serial
 * `products.id`. Host keys and SKU lists come from that file — the SDK
 * has no built-in tenant catalog.
 */
import { TwoKeyError } from "./errors.js";

export type HostCatalogSlice = {
  offeringCodes: readonly string[];
  addonCodes: readonly string[];
};

/**
 * Tenant `hosts.json` (written by that catalog’s `npm run validate`).
 * `productNames` are `catalog.json` product object keys.
 */
export type HostsCatalogDocument = {
  productNames?: readonly string[];
  /** @deprecated Prefer `productNames`. Still read for older fixtures. */
  productIds?: readonly string[];
  hosts: Record<string, HostCatalogSlice>;
};

export type OfferingCatalog = {
  /** Catalog product names this binary gates (`hosts.json` `productNames`). */
  productNames?: readonly string[];
  /**
   * @deprecated Prefer `productNames`. Still matched against JWT
   * `product_id` / `product_code` / `product_name`.
   */
  productIds?: readonly string[];
  offeringCodes: readonly string[];
  addonCodes: readonly string[];
};

function inSet(haystack: readonly string[], needle: string, caseInsensitive = false): boolean {
  const n = needle.trim();
  if (!n) return false;
  if (!caseInsensitive) return haystack.includes(n);
  const lower = n.toLowerCase();
  return haystack.some((h) => h.toLowerCase() === lower);
}

function pushUnique(list: string[], value: string): void {
  if (!list.includes(value)) list.push(value);
}

/**
 * Product identity strings this catalog knows (names first, then legacy ids).
 */
export function catalogProductKeys(catalog: OfferingCatalog): readonly string[] {
  const keys: string[] = [];
  for (const name of catalog.productNames ?? []) {
    if (typeof name === "string" && name.trim() !== "") pushUnique(keys, name.trim());
  }
  for (const id of catalog.productIds ?? []) {
    if (typeof id === "string" && id.trim() !== "") pushUnique(keys, id.trim());
  }
  return keys;
}

/** True when [catalog] includes [productId] as a name or legacy id. */
export function catalogKnowsProduct(catalog: OfferingCatalog, productId: string): boolean {
  return inSet(catalogProductKeys(catalog), productId);
}

/** True when [catalog] includes [offeringCode]. */
export function catalogKnowsOffering(catalog: OfferingCatalog, offeringCode: string): boolean {
  return inSet(catalog.offeringCodes, offeringCode);
}

/** True when [catalog] includes [addonCode] (case-insensitive). */
export function catalogKnowsAddon(catalog: OfferingCatalog, addonCode: string): boolean {
  return inSet(catalog.addonCodes, addonCode, true);
}

function asStringArray(value: unknown, label: string): string[] {
  if (!Array.isArray(value)) {
    throw new TwoKeyError("config", `${label} must be an array of strings`);
  }
  const out: string[] = [];
  for (const item of value) {
    if (typeof item !== "string" || item.trim() === "") {
      throw new TwoKeyError("config", `${label} must be an array of strings`);
    }
    out.push(item);
  }
  return out;
}

function parseHostSlice(raw: unknown, hostKey: string): HostCatalogSlice {
  if (raw == null || typeof raw !== "object" || Array.isArray(raw)) {
    throw new TwoKeyError("config", `hosts.${hostKey} must be an object`);
  }
  const row = raw as Record<string, unknown>;
  return {
    offeringCodes: asStringArray(row.offeringCodes, `hosts.${hostKey}.offeringCodes`),
    addonCodes: asStringArray(row.addonCodes, `hosts.${hostKey}.addonCodes`),
  };
}

/**
 * Parse seed-repo `hosts.json`. Does not fetch — apps bake the file at build time.
 */
export function parseHostsCatalog(raw: unknown): HostsCatalogDocument {
  if (raw == null || typeof raw !== "object" || Array.isArray(raw)) {
    throw new TwoKeyError("config", "hosts.json must be an object");
  }
  const doc = raw as Record<string, unknown>;
  if (doc.hosts == null || typeof doc.hosts !== "object" || Array.isArray(doc.hosts)) {
    throw new TwoKeyError("config", "hosts.json hosts must be an object");
  }
  const hosts: Record<string, HostCatalogSlice> = {};
  for (const [key, slice] of Object.entries(doc.hosts as Record<string, unknown>)) {
    hosts[key] = parseHostSlice(slice, key);
  }
  const productNames =
    doc.productNames != null ? asStringArray(doc.productNames, "productNames") : undefined;
  const productIds =
    doc.productIds != null ? asStringArray(doc.productIds, "productIds") : undefined;
  return { productNames, productIds, hosts };
}

/**
 * Offering catalog for one host key from the tenant’s baked `hosts.json`.
 */
export function catalogForHost(raw: unknown, hostKey: string): OfferingCatalog {
  const doc = parseHostsCatalog(raw);
  const slice = doc.hosts[hostKey];
  if (slice == null) {
    throw new TwoKeyError("config", `unknown host catalog: ${hostKey}`);
  }
  const productNames = doc.productNames ?? doc.productIds ?? [];
  return {
    productNames,
    offeringCodes: slice.offeringCodes,
    addonCodes: slice.addonCodes,
  };
}
