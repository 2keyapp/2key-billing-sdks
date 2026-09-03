import { authBaseUrl } from "./portal.js";
import { TwoKeyError } from "../billing/errors.js";
import type { SdkConfig } from "../billing/config.js";

export type EmailAuthUser = {
  id?: string;
  email?: string;
  name?: string;
};

export type EmailAuthResult = {
  user: EmailAuthUser;
};

export type OAuthProviderInfo = {
  id: string;
  enabled: boolean;
  redirectUri?: string;
};

export type OAuthProvidersDocument = {
  issuer: string;
  providers: OAuthProviderInfo[];
};

function asRecord(v: unknown): Record<string, unknown> {
  return v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : {};
}

async function postAuthJson(
  config: SdkConfig,
  path: string,
  body: Record<string, unknown>,
  fetchImpl: typeof fetch,
): Promise<Record<string, unknown>> {
  const url = `${authBaseUrl(config)}${path}`;
  let res: Response;
  try {
    res = await fetchImpl(url, {
      method: "POST",
      headers: { Accept: "application/json", "Content-Type": "application/json" },
      credentials: "include",
      body: JSON.stringify(body),
    });
  } catch (e) {
    throw new TwoKeyError("network", "Network error talking to billing auth", String(e));
  }
  const json = await res.json().catch(() => ({}));
  const rec = asRecord(json);
  if (res.status === 401 || res.status === 403) {
    const message =
      (typeof rec.message === "string" && rec.message) ||
      (typeof rec.error === "string" && rec.error) ||
      `Auth request failed (HTTP ${res.status}).`;
    throw new TwoKeyError("unauthorized", message);
  }
  if (!res.ok) {
    const message =
      (typeof rec.message === "string" && rec.message) ||
      (typeof rec.error === "string" && rec.error) ||
      `Auth request failed (HTTP ${res.status}).`;
    throw new TwoKeyError("unknown", message);
  }
  return rec.data && typeof rec.data === "object" ? asRecord(rec.data) : rec;
}

function userFromBody(body: Record<string, unknown>): EmailAuthUser {
  const user = asRecord(body.user);
  return {
    id: typeof user.id === "string" ? user.id : undefined,
    email: typeof user.email === "string" ? user.email : undefined,
    name: typeof user.name === "string" ? user.name : undefined,
  };
}

/**
 * `POST /api/auth/sign-in/email` — establishes a Better Auth session cookie.
 * Does not export Better Auth types.
 */
export async function signInWithEmail(
  config: SdkConfig,
  opts: { email: string; password: string; fetchImpl?: typeof fetch },
): Promise<EmailAuthResult> {
  const fetchImpl = opts.fetchImpl ?? fetch.bind(globalThis);
  const body = await postAuthJson(
    config,
    "/sign-in/email",
    { email: opts.email, password: opts.password },
    fetchImpl,
  );
  return { user: userFromBody(body) };
}

/**
 * `POST /api/auth/sign-up/email` — register and establish a session cookie.
 */
export async function signUpWithEmail(
  config: SdkConfig,
  opts: { email: string; password: string; name: string; fetchImpl?: typeof fetch },
): Promise<EmailAuthResult> {
  const fetchImpl = opts.fetchImpl ?? fetch.bind(globalThis);
  const body = await postAuthJson(
    config,
    "/sign-up/email",
    { email: opts.email, password: opts.password, name: opts.name },
    fetchImpl,
  );
  return { user: userFromBody(body) };
}

/**
 * `GET /api/auth/.well-known/oauth-providers` — enabled login methods.
 */
export async function fetchOAuthProviders(
  config: SdkConfig,
  opts?: { fetchImpl?: typeof fetch },
): Promise<OAuthProvidersDocument> {
  const fetchImpl = opts?.fetchImpl ?? fetch.bind(globalThis);
  const url = `${authBaseUrl(config)}/.well-known/oauth-providers`;
  let res: Response;
  try {
    res = await fetchImpl(url, { method: "GET", headers: { Accept: "application/json" } });
  } catch (e) {
    throw new TwoKeyError("network", "Network error fetching OAuth providers", String(e));
  }
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new TwoKeyError("unknown", `Provider discovery failed (HTTP ${res.status}).`);
  }
  const rec = asRecord(json);
  const data = rec.data && typeof rec.data === "object" ? asRecord(rec.data) : rec;
  const raw = data.providers;
  const providers: OAuthProviderInfo[] = Array.isArray(raw)
    ? raw
        .filter((p): p is Record<string, unknown> => !!p && typeof p === "object")
        .map((p) => ({
          id: typeof p.id === "string" ? p.id : "",
          enabled: p.enabled === true,
          redirectUri: typeof p.redirectUri === "string" ? p.redirectUri : undefined,
        }))
        .filter((p) => p.id)
    : [];
  return {
    issuer: typeof data.issuer === "string" ? data.issuer : "",
    providers,
  };
}
