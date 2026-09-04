import { validateConfig, type SdkConfig } from "../billing/config.js";

const SESSION_KEY_SUFFIX = "ba-session-token";

function storageKey(config: SdkConfig): string {
  return `${validateConfig(config).storagePrefix}:${SESSION_KEY_SUFFIX}`;
}

function memoryStore(): Storage | null {
  try {
    if (typeof localStorage === "undefined") {
      return null;
    }
    return localStorage;
  } catch {
    return null;
  }
}

/** Persist the Better Auth session token for cookie-free hosts (Outlook). */
export function saveAuthSessionToken(config: SdkConfig, token: string): void {
  const store = memoryStore();
  if (!store) {
    return;
  }
  store.setItem(storageKey(config), token);
}

/** Read a previously saved Better Auth session token. */
export function readAuthSessionToken(config: SdkConfig): string {
  const store = memoryStore();
  if (!store) {
    return "";
  }
  return store.getItem(storageKey(config)) ?? "";
}

/** Drop the saved Better Auth session token. */
export function clearAuthSessionToken(config: SdkConfig): void {
  const store = memoryStore();
  store?.removeItem(storageKey(config));
}
