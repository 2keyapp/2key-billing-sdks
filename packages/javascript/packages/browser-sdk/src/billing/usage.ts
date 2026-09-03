import { TwoKeyError } from "./errors.js";
import { normalizeApiBaseUrl, type SdkConfig, validateConfig } from "./config.js";

/** Body for `POST /api/v1/usage/report` (reporter / M2M). */
export type UsageReportRequest = {
  meterKey: string;
  usingParty: string;
  payingParty: string;
  idempotencyKey: string;
  reporterType?: string;
  targetFqhn?: string;
  bytesToTarget?: string | number;
  bytesFromTarget?: string | number;
  quantity?: string | number;
  reporterId?: string;
  sessionId?: string;
  dimensions?: Record<string, unknown>;
  reportedAt?: string;
};

export type UsageReportResult = {
  accepted: boolean;
  duplicate: boolean;
  remaining: string | null;
  generation: number | null;
  actions?: string[];
};

function bearer(token: string): string {
  const t = token.trim();
  return t.toLowerCase().startsWith("bearer ") ? t : `Bearer ${t}`;
}

function unwrapData(body: unknown): Record<string, unknown> {
  if (body && typeof body === "object" && "data" in body) {
    const data = (body as { data: unknown }).data;
    if (data && typeof data === "object") return data as Record<string, unknown>;
  }
  return (body ?? {}) as Record<string, unknown>;
}

/**
 * Report usage to billing (server-to-server / relay).
 * Auth: `USAGE_REPORTER_TOKEN` bearer — not end-user session.
 */
export async function reportUsage(
  config: SdkConfig,
  opts: {
    reporterToken: string;
    body: UsageReportRequest;
    fetchImpl?: typeof fetch;
  },
): Promise<UsageReportResult> {
  const fetchImpl = opts.fetchImpl ?? fetch.bind(globalThis);
  const origin = normalizeApiBaseUrl(validateConfig(config).apiBaseUrl);
  const base = origin.endsWith("/") ? origin : `${origin}/`;
  const url = new URL("api/v1/usage/report", base).toString();

  const b = opts.body;
  const payload = {
    meter_key: b.meterKey,
    using_party: b.usingParty,
    paying_party: b.payingParty,
    idempotency_key: b.idempotencyKey,
    reporter_type: b.reporterType ?? "relay",
    target_fqhn: b.targetFqhn,
    bytes_to_target: b.bytesToTarget,
    bytes_from_target: b.bytesFromTarget,
    quantity: b.quantity,
    reporter_id: b.reporterId,
    session_id: b.sessionId,
    dimensions: b.dimensions ?? {},
    reported_at: b.reportedAt,
  };

  let res: Response;
  try {
    res = await fetchImpl(url, {
      method: "POST",
      headers: {
        Authorization: bearer(opts.reporterToken),
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(payload),
    });
  } catch (e) {
    throw new TwoKeyError("network", "Network error reporting usage", String(e));
  }

  if (res.status === 401 || res.status === 403) {
    throw new TwoKeyError("unauthorized", `Usage report failed (HTTP ${res.status}).`);
  }
  if (!res.ok) {
    throw new TwoKeyError("unknown", `Usage report failed (HTTP ${res.status}).`);
  }

  const body = unwrapData(await res.json());
  return {
    accepted: Boolean(body.accepted ?? true),
    duplicate: Boolean(body.duplicate ?? false),
    remaining: body.remaining == null ? null : String(body.remaining),
    generation:
      typeof body.generation === "number"
        ? body.generation
        : body.generation == null
          ? null
          : Number(body.generation),
    actions: Array.isArray(body.actions) ? body.actions.map(String) : undefined,
  };
}
