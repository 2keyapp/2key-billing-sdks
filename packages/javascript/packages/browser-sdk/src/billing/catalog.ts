/** Public plan from `GET /api/v1/plans`. */
export type Plan = {
  id: number;
  productId: number;
  name: string;
  description?: string;
  billingInterval: string;
  basePrice: number;
  currency: string;
  features: string[];
  featuresJson?: Record<string, unknown>;
  addonCode?: string;
  isActive: boolean;
};

function asInt(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === "string") {
    const n = Number.parseInt(value, 10);
    return Number.isFinite(n) ? n : 0;
  }
  return 0;
}

function asNumber(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const n = Number.parseFloat(value);
    return Number.isFinite(n) ? n : 0;
  }
  return 0;
}

/** Parse one plan object (camelCase or snake_case). */
export function parsePlan(raw: Record<string, unknown>): Plan {
  let features: string[] = [];
  let featuresJson: Record<string, unknown> | undefined;
  const featuresRaw = raw.featuresJson ?? raw.features_json;
  if (Array.isArray(featuresRaw)) {
    features = featuresRaw.map(String);
  } else if (featuresRaw && typeof featuresRaw === "object") {
    featuresJson = featuresRaw as Record<string, unknown>;
    const nested = featuresJson.features;
    if (Array.isArray(nested)) features = nested.map(String);
  }
  if (Array.isArray(raw.features)) {
    features = (raw.features as unknown[]).map(String);
  }

  const addon =
    (typeof raw.addonCode === "string" && raw.addonCode) ||
    (typeof raw.addon_code === "string" && raw.addon_code) ||
    undefined;

  return {
    id: asInt(raw.id),
    productId: asInt(raw.productId ?? raw.product_id),
    name: String(raw.name ?? ""),
    description: typeof raw.description === "string" ? raw.description : undefined,
    billingInterval: String(raw.billingInterval ?? raw.billing_interval ?? ""),
    basePrice: asNumber(raw.basePrice ?? raw.base_price),
    currency: String(raw.currency ?? ""),
    features,
    featuresJson,
    addonCode: addon,
    isActive:
      typeof raw.isActive === "boolean"
        ? raw.isActive
        : typeof raw.is_active === "boolean"
          ? raw.is_active
          : true,
  };
}
