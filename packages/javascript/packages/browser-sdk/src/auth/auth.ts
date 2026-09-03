import type { SdkConfig } from "../billing/config.js";
import { TwoKeyError } from "../billing/errors.js";
import { authBaseUrl, portalPathUrl } from "./portal.js";

export type AcquireApiTokenResult = {
  token: string;
  /** Present when server requires org selection before minting. */
  orgPickRequired?: boolean;
};

/**
 * Mint a billing API JWT from the browser Better Auth cookie session.
 * Host must call with `credentials: "include"` (default here).
 *
 * @see docs/auth-protocol.md
 */
export async function acquireApiToken(
  config: SdkConfig,
  opts?: {
    fetchImpl?: typeof fetch;
    /** Optional active organization id when server requires it. */
    organizationId?: string;
  },
): Promise<AcquireApiTokenResult> {
  const fetchImpl = opts?.fetchImpl ?? fetch.bind(globalThis);
  const url = `${authBaseUrl(config)}/token`;
  const headers: Record<string, string> = {
    Accept: "application/json",
  };
  if (opts?.organizationId?.trim()) {
    headers["X-Organization-Id"] = opts.organizationId.trim();
  }

  let res: Response;
  try {
    res = await fetchImpl(url, {
      method: "GET",
      headers,
      credentials: "include",
    });
  } catch (e) {
    throw new TwoKeyError("network", "Network error minting billing API token", String(e));
  }

  if (res.status === 401 || res.status === 403) {
    throw new TwoKeyError("unauthorized", `Auth token request failed (HTTP ${res.status}).`);
  }

  let body: unknown;
  try {
    body = await res.json();
  } catch (e) {
    throw new TwoKeyError("invalid_response", "Auth token response was not JSON", String(e));
  }

  const record = (body && typeof body === "object" ? body : {}) as Record<string, unknown>;
  const data =
    record.data && typeof record.data === "object"
      ? (record.data as Record<string, unknown>)
      : record;

  if (data.orgPickRequired === true || data.ORG_PICK_REQUIRED === true) {
    return { token: "", orgPickRequired: true };
  }

  const token =
    (typeof data.token === "string" && data.token) ||
    (typeof data.accessToken === "string" && data.accessToken) ||
    (typeof data.access_token === "string" && data.access_token) ||
    "";

  if (!token && res.ok) {
    throw new TwoKeyError("invalid_response", "Auth token response missing token.");
  }
  if (!res.ok) {
    throw new TwoKeyError("unknown", `Auth token request failed (HTTP ${res.status}).`);
  }
  return { token };
}

/**
 * Build a portal handoff URL. Host supplies the one-time token from Better Auth
 * `oneTimeToken` (or equivalent) — this helper only joins path + query.
 */
export function portalHandoffUrl(
  config: SdkConfig,
  opts: { redirectPath: string; ott: string; query?: Record<string, string> },
): string {
  const base = portalPathUrl(config, "/auth/handoff");
  const u = new URL(base);
  const redirect = opts.redirectPath.startsWith("/")
    ? opts.redirectPath
    : `/${opts.redirectPath}`;
  u.searchParams.set("redirect", redirect);
  u.searchParams.set("ott", opts.ott);
  if (opts.query) {
    for (const [k, v] of Object.entries(opts.query)) {
      u.searchParams.set(k, v);
    }
  }
  return u.toString();
}
