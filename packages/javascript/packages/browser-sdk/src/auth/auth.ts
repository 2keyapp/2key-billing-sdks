import type { SdkConfig } from "../billing/config.js";
import { TwoKeyError } from "../billing/errors.js";
import { readAuthSessionToken, saveAuthSessionToken } from "./auth-session-store.js";
import { authBaseUrl, portalPathUrl } from "./portal.js";

/** Personal paying-party slug. Using-party hosts bind this when the session has no org. */
export const PERSONAL_ORG_SLUG = "me";

export type AcquireApiTokenResult = {
  token: string;
  /** Session has no bound org (`ORG_SLUG_REQUIRED`). Paying-party UIs pick a slug. */
  orgPickRequired?: boolean;
};

export type BindOrganizationResult = {
  organizationId: string;
  slug: string;
  name: string;
  role: string;
};

export type AuthSessionOpts = {
  fetchImpl?: typeof fetch;
  /** Optional active organization id when server requires it. */
  organizationId?: string;
  /** Better Auth session token (bearer plugin). Defaults to the stored OTT exchange. */
  sessionToken?: string;
};

function asRecord(v: unknown): Record<string, unknown> {
  return v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : {};
}

function sessionTokenFromVerifyBody(body: Record<string, unknown>): string {
  const data = body.data && typeof body.data === "object" ? asRecord(body.data) : body;
  const session = asRecord(data.session);
  const nested = asRecord(session.session);
  const token =
    (typeof session.token === "string" && session.token) ||
    (typeof nested.token === "string" && nested.token) ||
    (typeof data.token === "string" && data.token) ||
    "";
  return token;
}

function stringField(row: Record<string, unknown>, key: string): string {
  const v = row[key];
  return typeof v === "string" && v.trim() ? v.trim() : "";
}

function nestedErrorRecord(body: Record<string, unknown>): Record<string, unknown> {
  return body.error && typeof body.error === "object" && !Array.isArray(body.error)
    ? asRecord(body.error)
    : {};
}

/** True when GET /token (or bind) says the session has no active organization. */
export function isOrgSlugRequiredBody(body: unknown): boolean {
  const record = asRecord(body);
  const nested = nestedErrorRecord(record);
  const code = stringField(record, "code") || stringField(nested, "code");
  if (code === "ORG_SLUG_REQUIRED" || code === "ORG_PICK_REQUIRED") {
    return true;
  }
  if (record.orgPickRequired === true || record.ORG_PICK_REQUIRED === true) {
    return true;
  }
  const message = `${stringField(record, "message")} ${stringField(nested, "message")}`.toUpperCase();
  return message.includes("ORG_SLUG_REQUIRED") || message.includes("ORG_PICK_REQUIRED");
}

function authSessionHeaders(config: SdkConfig, opts?: AuthSessionOpts): Record<string, string> {
  const headers: Record<string, string> = {
    Accept: "application/json",
  };
  if (opts?.organizationId?.trim()) {
    headers["X-Organization-Id"] = opts.organizationId.trim();
  }
  const sessionToken = opts?.sessionToken?.trim() || readAuthSessionToken(config);
  if (sessionToken) {
    headers.Authorization = `Bearer ${sessionToken}`;
  }
  return headers;
}

/**
 * Mint a billing API JWT from the Better Auth session.
 * Uses `credentials: "include"` plus a stored session bearer when cookies cannot
 * cross from the Outlook add-in origin (no third-party cookies).
 *
 * Unbound sessions return `{ orgPickRequired: true }` (`403 ORG_SLUG_REQUIRED`).
 * Using-party hosts should call {@link acquireUsingPartyApiToken} instead.
 */
export async function acquireApiToken(
  config: SdkConfig,
  opts?: AuthSessionOpts,
): Promise<AcquireApiTokenResult> {
  const fetchImpl = opts?.fetchImpl ?? fetch.bind(globalThis);
  const url = `${authBaseUrl(config)}/token`;

  let res: Response;
  try {
    res = await fetchImpl(url, {
      method: "GET",
      headers: authSessionHeaders(config, opts),
      credentials: "include",
    });
  } catch (e) {
    throw new TwoKeyError("network", "Network error minting billing API token", String(e));
  }

  let body: unknown;
  try {
    body = await res.json();
  } catch (e) {
    if (res.status === 401 || res.status === 403) {
      throw new TwoKeyError("unauthorized", `Auth token request failed (HTTP ${res.status}).`);
    }
    throw new TwoKeyError("invalid_response", "Auth token response was not JSON", String(e));
  }

  const record = asRecord(body);
  const data =
    record.data && typeof record.data === "object" ? asRecord(record.data) : record;

  if (isOrgSlugRequiredBody(record) || isOrgSlugRequiredBody(data)) {
    return { token: "", orgPickRequired: true };
  }

  if (res.status === 401) {
    throw new TwoKeyError("unauthorized", `Auth token request failed (HTTP ${res.status}).`);
  }
  if (res.status === 403) {
    throw new TwoKeyError("unauthorized", `Auth token request failed (HTTP ${res.status}).`);
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
 * Bind the current session to an organization slug (`POST /api/auth/organization/bind`).
 */
export async function bindOrganization(
  config: SdkConfig,
  slug: string = PERSONAL_ORG_SLUG,
  opts?: AuthSessionOpts,
): Promise<BindOrganizationResult> {
  const fetchImpl = opts?.fetchImpl ?? fetch.bind(globalThis);
  const trimmed = slug.trim() || PERSONAL_ORG_SLUG;
  const url = `${authBaseUrl(config)}/organization/bind`;

  let res: Response;
  try {
    res = await fetchImpl(url, {
      method: "POST",
      headers: {
        ...authSessionHeaders(config, opts),
        "Content-Type": "application/json",
      },
      credentials: "include",
      body: JSON.stringify({ slug: trimmed }),
    });
  } catch (e) {
    throw new TwoKeyError("network", "Network error binding organization", String(e));
  }

  const json = await res.json().catch(() => ({}));
  const record = asRecord(json);
  const data =
    record.data && typeof record.data === "object" ? asRecord(record.data) : record;

  if (!res.ok) {
    const message =
      stringField(record, "message") ||
      stringField(data, "message") ||
      `Organization bind failed (HTTP ${res.status}).`;
    throw new TwoKeyError(
      res.status === 401 || res.status === 403 ? "unauthorized" : "unknown",
      message,
    );
  }

  const organizationId = stringField(data, "organizationId") || stringField(record, "organizationId");
  const boundSlug = stringField(data, "slug") || stringField(record, "slug");
  const name = stringField(data, "name") || stringField(record, "name") || boundSlug;
  const role = stringField(data, "role") || stringField(record, "role");
  if (!organizationId || !boundSlug || !role) {
    throw new TwoKeyError("invalid_response", "Organization bind response was missing fields.");
  }
  return { organizationId, slug: boundSlug, name, role };
}

/**
 * Using-party mint: bind personal slug `me` when the session has no org, then remint.
 * License JWTs stay identity-wide (all assigned seats). Paying-party portal still
 * asks the user to type a slug.
 */
export async function acquireUsingPartyApiToken(
  config: SdkConfig,
  opts?: AuthSessionOpts,
): Promise<AcquireApiTokenResult> {
  const first = await acquireApiToken(config, opts);
  if (first.token && !first.orgPickRequired) {
    return first;
  }
  await bindOrganization(config, PERSONAL_ORG_SLUG, opts);
  const second = await acquireApiToken(config, opts);
  if (!second.token || second.orgPickRequired) {
    throw new TwoKeyError(
      "unauthorized",
      "Signed in, but could not bind a personal billing context.",
    );
  }
  return second;
}

/**
 * Exchange a one-time token from `{billing}/oauth/office-complete` for a session
 * bearer, persist it, and mint the billing API JWT.
 */
export async function exchangeOneTimeToken(
  config: SdkConfig,
  ott: string,
  opts?: AuthSessionOpts & { usingParty?: boolean },
): Promise<AcquireApiTokenResult> {
  const token = ott.trim();
  if (!token) {
    throw new TwoKeyError("invalid_response", "One-time token is empty.");
  }
  const fetchImpl = opts?.fetchImpl ?? fetch.bind(globalThis);
  const url = `${authBaseUrl(config)}/one-time-token/verify`;
  let res: Response;
  try {
    res = await fetchImpl(url, {
      method: "POST",
      headers: { Accept: "application/json", "Content-Type": "application/json" },
      credentials: "include",
      body: JSON.stringify({ token }),
    });
  } catch (e) {
    throw new TwoKeyError("network", "Network error verifying one-time token", String(e));
  }

  const json = await res.json().catch(() => ({}));
  const rec = asRecord(json);
  if (!res.ok) {
    const message =
      (typeof rec.message === "string" && rec.message) ||
      (typeof rec.error === "string" && rec.error) ||
      `One-time token verify failed (HTTP ${res.status}).`;
    throw new TwoKeyError(
      res.status === 401 || res.status === 403 ? "unauthorized" : "unknown",
      message,
    );
  }

  const headerToken = res.headers.get("set-auth-token")?.trim() ?? "";
  const sessionToken = sessionTokenFromVerifyBody(rec) || headerToken;
  if (!sessionToken) {
    throw new TwoKeyError("invalid_response", "One-time token verify did not return a session.");
  }
  saveAuthSessionToken(config, sessionToken);
  const mintOpts = { fetchImpl, sessionToken };
  return opts?.usingParty
    ? acquireUsingPartyApiToken(config, mintOpts)
    : acquireApiToken(config, mintOpts);
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
