import { normalizeApiBaseUrl, type SdkConfig, validateConfig } from "./config.js";
import { TwoKeyError } from "./errors.js";
import type { LicensePayload } from "./license.js";
import { parseLicenseClaims } from "./license.js";

export type SyncResult =
  | { kind: "success"; signedToken: string; etag?: string }
  | { kind: "not_modified"; etag?: string };

function unwrapData(body: unknown): Record<string, unknown> {
  if (body && typeof body === "object" && "data" in body) {
    const data = (body as { data: unknown }).data;
    if (data && typeof data === "object") return data as Record<string, unknown>;
  }
  return (body ?? {}) as Record<string, unknown>;
}

function bearer(token: string): string {
  const t = token.trim();
  return t.toLowerCase().startsWith("bearer ") ? t : `Bearer ${t}`;
}

/** Minimal browser `/api/v1` client (cookie session via credentials: include). */
export class BillingApiClient {
  private readonly origin: string;

  constructor(
    config: SdkConfig,
    private readonly fetchImpl: typeof fetch = fetch.bind(globalThis),
  ) {
    this.origin = normalizeApiBaseUrl(validateConfig(config).apiBaseUrl);
  }

  private url(path: string): string {
    const base = this.origin.endsWith("/") ? this.origin : `${this.origin}/`;
    return new URL(path.replace(/^\//, ""), base).toString();
  }

  async fetchLicense(opts: {
    accessToken: string;
    payingPartyId?: string;
    ifNoneMatch?: string;
  }): Promise<SyncResult> {
    if (!opts.accessToken.trim()) {
      throw new TwoKeyError("unauthorized", "Authorization token is required.");
    }
    const headers: Record<string, string> = {
      Authorization: bearer(opts.accessToken),
    };
    if (opts.payingPartyId?.trim()) {
      headers["X-Paying-Party-Id"] = opts.payingPartyId.trim();
    }
    if (opts.ifNoneMatch?.trim()) {
      const e = opts.ifNoneMatch.trim();
      headers["If-None-Match"] = e.startsWith('"') ? e : `"${e}"`;
    }

    let res: Response;
    try {
      res = await this.fetchImpl(this.url("api/v1/license"), {
        method: "GET",
        headers,
        credentials: "include",
      });
    } catch (e) {
      throw new TwoKeyError("network", "Network error talking to billing server", String(e));
    }

    const etag = res.headers.get("etag") ?? undefined;
    if (res.status === 304) {
      return { kind: "not_modified", etag: etag ?? opts.ifNoneMatch };
    }
    if (res.status === 200) {
      const body = await res.json();
      const data = unwrapData(body);
      const signed =
        (typeof data.signedToken === "string" && data.signedToken) ||
        (typeof data.signed_token === "string" && data.signed_token) ||
        (typeof data.token === "string" && data.token) ||
        "";
      if (!signed) {
        throw new TwoKeyError(
          "invalid_response",
          "Invalid response from billing server. Try again or report this issue.",
        );
      }
      return { kind: "success", signedToken: signed, etag };
    }
    if (res.status === 401 || res.status === 403) {
      throw new TwoKeyError("unauthorized", `Billing request failed (HTTP ${res.status}).`);
    }
    throw new TwoKeyError("unknown", `Billing request failed (HTTP ${res.status}).`);
  }

  /** Decode claims only — call after Web Crypto ES256 verify (Phase 6.3). */
  parseClaims(claims: unknown): LicensePayload {
    return parseLicenseClaims(claims);
  }
}
