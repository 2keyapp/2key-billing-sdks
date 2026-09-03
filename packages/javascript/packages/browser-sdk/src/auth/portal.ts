import {
  normalizeApiBaseUrl,
  validateConfig,
  type SdkConfig,
} from "../billing/config.js";

function originSlash(origin: string): string {
  return origin.endsWith("/") ? origin : `${origin}/`;
}

/** Resolve portal origin (defaults to API origin). */
export function resolvedPortalBaseUrl(config: SdkConfig): string {
  const c = validateConfig(config);
  const portal = c.portalBaseUrl?.trim();
  return portal && portal.length > 0 ? normalizeApiBaseUrl(portal) : c.apiBaseUrl;
}

/** Shop / marketplace URL. */
export function shopUrl(config: SdkConfig): string {
  const c = validateConfig(config);
  const base = resolvedPortalBaseUrl(c);
  const path = (c.shopPath || "/shop").replace(/^\//, "");
  return `${originSlash(base)}${path}`;
}

/**
 * Build a portal path URL (caller appends handoff query from auth layer).
 * Example: portalPathUrl(config, "/subscriptions")
 */
export function portalPathUrl(config: SdkConfig, redirectPath: string): string {
  const base = resolvedPortalBaseUrl(config);
  const path = redirectPath.startsWith("/") ? redirectPath.slice(1) : redirectPath;
  return `${originSlash(base)}${path}`;
}

/**
 * Start Better Auth social sign-in redirect (browser).
 * Host must register `callbackURL` in trusted origins / deep-link schemes on server.
 */
export function socialSignInUrl(
  config: SdkConfig,
  opts: { provider: string; callbackURL: string },
): string {
  const c = validateConfig(config);
  const u = new URL("api/auth/sign-in/social", originSlash(c.apiBaseUrl));
  // Better Auth typically expects POST; this helper is for documenting the
  // callback URL shape. Prefer fetch POST from the host app.
  u.searchParams.set("provider", opts.provider);
  u.searchParams.set("callbackURL", opts.callbackURL);
  return u.toString();
}

/** Auth base path on the billing origin. */
export function authBaseUrl(config: SdkConfig): string {
  const c = validateConfig(config);
  return `${originSlash(c.apiBaseUrl)}api/auth`;
}
