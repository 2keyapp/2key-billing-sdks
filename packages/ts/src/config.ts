/** Strip trailing slashes and optional /api/v1 or /api/billing. */
export function normalizeApiBaseUrl(input: string): string {
  let s = input.trim();
  while (s.endsWith("/")) s = s.slice(0, -1);
  const lower = s.toLowerCase();
  for (const suffix of ["/api/v1", "/api/billing"]) {
    if (lower.endsWith(suffix)) {
      s = s.slice(0, -suffix.length);
      while (s.endsWith("/")) s = s.slice(0, -1);
      break;
    }
  }
  return s;
}

export type SdkConfig = {
  apiBaseUrl: string;
  /** EC public key PEM for license JWT (ES256). */
  publicKeyPem: string;
  /** Required host-specific storage namespace. */
  storagePrefix: string;
  portalBaseUrl?: string;
  shopPath?: string;
  deepLinkScheme?: string;
};

export function validateConfig(config: SdkConfig): SdkConfig {
  const apiBaseUrl = normalizeApiBaseUrl(config.apiBaseUrl);
  if (!apiBaseUrl) throw new Error("apiBaseUrl is required");
  if (!config.publicKeyPem?.trim()) throw new Error("publicKeyPem is required");
  if (!config.storagePrefix?.trim()) throw new Error("storagePrefix is required");
  return {
    ...config,
    apiBaseUrl,
    storagePrefix: config.storagePrefix.trim(),
    shopPath: config.shopPath?.trim() || "/shop",
  };
}
