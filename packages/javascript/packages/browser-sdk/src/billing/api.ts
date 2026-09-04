import { normalizeApiBaseUrl, type SdkConfig, validateConfig } from "./config.js";
import { parsePlan, type Plan } from "./catalog.js";
import { TwoKeyError } from "./errors.js";
import type { LicensePayload } from "./license.js";
import { parseLicenseClaims } from "./license.js";

export type SyncResult =
  | { kind: "success"; signedToken: string; etag?: string }
  | { kind: "not_modified"; etag?: string };

export type BootstrapResult =
  | { kind: "success"; data: Record<string, unknown> }
  | { kind: "failure"; message: string; status?: number };

export type FetchPlansQuery = {
  productId?: number;
  billingInterval?: "monthly" | "annual" | string;
  includeInactive?: boolean;
};

function unwrapData(body: unknown): Record<string, unknown> {
  if (body && typeof body === "object" && "data" in body) {
    const data = (body as { data: unknown }).data;
    if (data && typeof data === "object") return data as Record<string, unknown>;
  }
  return (body ?? {}) as Record<string, unknown>;
}

function unwrapList(body: unknown): unknown[] {
  if (!body || typeof body !== "object") return [];
  const o = body as Record<string, unknown>;
  if (Array.isArray(o.data)) return o.data;
  if (Array.isArray(o.items)) return o.items;
  if (o.data && typeof o.data === "object") {
    const d = o.data as Record<string, unknown>;
    if (Array.isArray(d.items)) return d.items;
    if (Array.isArray(d.plans)) return d.plans;
  }
  return [];
}

function bearer(token: string): string {
  const t = token.trim();
  return t.toLowerCase().startsWith("bearer ") ? t : `Bearer ${t}`;
}

/** Browser `/api/v1` client (cookie session via credentials: include where needed). */
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

  /** `GET /api/v1/subscriptions/me` — bootstrap billing context. */
  async ensureBillingContext(opts: { accessToken: string }): Promise<BootstrapResult> {
    if (!opts.accessToken.trim()) {
      return { kind: "failure", message: "Authorization token is required." };
    }
    let res: Response;
    try {
      res = await this.fetchImpl(this.url("api/v1/subscriptions/me"), {
        method: "GET",
        headers: { Authorization: bearer(opts.accessToken) },
        credentials: "include",
      });
    } catch (e) {
      throw new TwoKeyError("network", "Network error talking to billing server", String(e));
    }
    if (res.status === 200) {
      const body = await res.json();
      return { kind: "success", data: unwrapData(body) };
    }
    if (res.status === 401 || res.status === 403) {
      return {
        kind: "failure",
        message: `Billing bootstrap failed (HTTP ${res.status}).`,
        status: res.status,
      };
    }
    return {
      kind: "failure",
      message: `Billing bootstrap failed (HTTP ${res.status}).`,
      status: res.status,
    };
  }

  /** `GET /api/v1/plans` — public catalog (no auth). */
  async fetchPlans(query: FetchPlansQuery = {}): Promise<Plan[]> {
    const u = new URL(this.url("api/v1/plans"));
    if (query.productId != null) u.searchParams.set("productId", String(query.productId));
    if (query.billingInterval) u.searchParams.set("billingInterval", query.billingInterval);
    if (query.includeInactive) u.searchParams.set("includeInactive", "true");

    let res: Response;
    try {
      res = await this.fetchImpl(u.toString(), { method: "GET", credentials: "include" });
    } catch (e) {
      throw new TwoKeyError("network", "Network error fetching plans", String(e));
    }
    if (res.status !== 200) {
      return [];
    }
    const body = await res.json();
    return unwrapList(body)
      .filter((row): row is Record<string, unknown> => !!row && typeof row === "object")
      .map(parsePlan);
  }

  /** Decode claims only — call after Web Crypto ES256 verify. */
  parseClaims(claims: unknown): LicensePayload {
    return parseLicenseClaims(claims);
  }

  /** `GET /api/v1/license/devices` — assigned seats and bound devices. */
  async listLicenseDevices(opts: { accessToken: string }): Promise<{ seats: unknown[] }> {
    if (!opts.accessToken.trim()) {
      throw new TwoKeyError("unauthorized", "Authorization token is required.");
    }
    let res: Response;
    try {
      res = await this.fetchImpl(this.url("api/v1/license/devices"), {
        method: "GET",
        headers: { Authorization: bearer(opts.accessToken) },
        credentials: "include",
      });
    } catch (e) {
      throw new TwoKeyError("network", "Network error listing license devices", String(e));
    }
    const body = await res.json().catch(() => ({}));
    if (!res.ok) throwHttp(res, body, "listLicenseDevices");
    const data = unwrapData(body);
    const seats = Array.isArray(data.seats) ? data.seats : [];
    return { seats };
  }

  /** `POST /api/v1/license/devices` — bind Ed25519 publicJwk to a seat. */
  async bindLicenseDevice(input: BindLicenseDeviceInput): Promise<BindLicenseDeviceResult> {
    if (!input.accessToken.trim()) {
      throw new TwoKeyError("unauthorized", "Authorization token is required.");
    }
    let res: Response;
    try {
      res = await this.fetchImpl(this.url("api/v1/license/devices"), {
        method: "POST",
        headers: {
          Authorization: bearer(input.accessToken),
          "Content-Type": "application/json",
        },
        credentials: "include",
        body: JSON.stringify({
          publicJwk: input.publicJwk,
          ...(input.friendlyName ? { friendlyName: input.friendlyName } : {}),
          ...(input.subscriptionId ? { subscriptionId: input.subscriptionId } : {}),
          platform: input.platform ?? "web",
          ...(input.replaceSki ? { replaceSki: input.replaceSki } : {}),
          issueLicense: input.issueLicense ?? true,
        }),
      });
    } catch (e) {
      throw new TwoKeyError("network", "Network error binding license device", String(e));
    }
    const body = await res.json().catch(() => ({}));
    if (!res.ok) throwHttp(res, body, "bindLicenseDevice");
    const data = unwrapData(body);
    const signed =
      (typeof data.signedToken === "string" && data.signedToken) ||
      (typeof data.signed_token === "string" && data.signed_token) ||
      undefined;
    return {
      device: asRecord(data.device),
      seat: asRecord(data.seat),
      replacedSki: typeof data.replacedSki === "string" ? data.replacedSki : undefined,
      signedToken: signed,
    };
  }

  /** `DELETE /api/v1/license/devices/:ski` — revoke a bound device. */
  async revokeLicenseDevice(opts: {
    accessToken: string;
    ski: string;
    deviceId?: string;
    subscriptionId?: string;
  }): Promise<void> {
    if (!opts.accessToken.trim()) {
      throw new TwoKeyError("unauthorized", "Authorization token is required.");
    }
    const u = new URL(this.url(`api/v1/license/devices/${encodeURIComponent(opts.ski)}`));
    if (opts.deviceId?.trim()) u.searchParams.set("deviceId", opts.deviceId.trim());
    if (opts.subscriptionId?.trim()) u.searchParams.set("subscriptionId", opts.subscriptionId.trim());
    let res: Response;
    try {
      res = await this.fetchImpl(u.toString(), {
        method: "DELETE",
        headers: { Authorization: bearer(opts.accessToken) },
        credentials: "include",
      });
    } catch (e) {
      throw new TwoKeyError("network", "Network error revoking license device", String(e));
    }
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throwHttp(res, body, "revokeLicenseDevice");
    }
  }
}

export type LicenseDevicePlatform = "web" | "ios" | "android" | "desktop" | "unknown";

export type LicenseDeviceSummary = {
  deviceId: string;
  ski: string;
  platform: string;
  friendlyName?: string;
  createdAt?: string;
};

export type LicenseDeviceSeat = {
  subscriptionId: string;
  memberId: string;
  planId: string;
  planName?: string;
  addonCode?: string;
  maxDevices: number;
  devices: LicenseDeviceSummary[];
};

export type BindLicenseDeviceInput = {
  accessToken: string;
  publicJwk: Record<string, unknown>;
  friendlyName?: string;
  subscriptionId?: string;
  platform?: LicenseDevicePlatform;
  replaceSki?: string;
  issueLicense?: boolean;
};

export type BindLicenseDeviceResult = {
  device: Record<string, unknown>;
  seat: Record<string, unknown>;
  replacedSki?: string;
  signedToken?: string;
};

function asRecord(v: unknown): Record<string, unknown> {
  return v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : {};
}

function throwHttp(res: Response, body: unknown, operation: string): never {
  const rec = asRecord(body);
  const errObj = asRecord(rec.error);
  const message =
    (typeof rec.error === "string" && rec.error) ||
    (typeof rec.message === "string" && rec.message) ||
    (typeof errObj.message === "string" && errObj.message) ||
    `${operation} failed (HTTP ${res.status}).`;
  const code =
    (typeof rec.code === "string" && rec.code) ||
    (typeof errObj.code === "string" && errObj.code) ||
    undefined;
  const details = rec.details ?? errObj.details;
  if (res.status === 409) {
    throw new TwoKeyError("conflict", message, code ?? "DEVICE_LIMIT_REACHED", details);
  }
  if (res.status === 401 || res.status === 403) {
    throw new TwoKeyError("unauthorized", message);
  }
  throw new TwoKeyError("unknown", message, code, details);
}
