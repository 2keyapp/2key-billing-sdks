/**
 * Host-declared product / offering / add-on codes this binary knows how to gate.
 *
 * Runtime gates are `static catalog ∩ verified license JWT`.
 * Unknown JWT codes are ignored; catalog codes missing from the JWT fail closed.
 */
export type OfferingCatalog = {
  productIds: readonly string[];
  offeringCodes: readonly string[];
  addonCodes: readonly string[];
};

function inSet(haystack: readonly string[], needle: string, caseInsensitive = false): boolean {
  const n = needle.trim();
  if (!caseInsensitive) return haystack.includes(n);
  const lower = n.toLowerCase();
  return haystack.some((h) => h.toLowerCase() === lower);
}

/** True when [catalog] includes [productId]. */
export function catalogKnowsProduct(catalog: OfferingCatalog, productId: string): boolean {
  return inSet(catalog.productIds, productId);
}

/** True when [catalog] includes [offeringCode]. */
export function catalogKnowsOffering(catalog: OfferingCatalog, offeringCode: string): boolean {
  return inSet(catalog.offeringCodes, offeringCode);
}

/** True when [catalog] includes [addonCode] (case-insensitive). */
export function catalogKnowsAddon(catalog: OfferingCatalog, addonCode: string): boolean {
  return inSet(catalog.addonCodes, addonCode, true);
}
