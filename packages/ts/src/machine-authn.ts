export type MachineAuthnClientOptions = {
  /** Billing host or full `/api/v1` base, e.g. `https://billing.example.com` */
  readonly baseUrl: string;
  readonly fetch?: typeof fetch;
  readonly authorization?: string;
  readonly headers?: HeadersInit;
};

const MACHINE_AUTHN = "/machine-authn";

function normalizeOrigin(input: string): string {
  let s = input.trim().replace(/\/+$/, "");
  for (const suffix of ["/api/v1", "/api/billing"]) {
    if (s.toLowerCase().endsWith(suffix)) {
      s = s.slice(0, -suffix.length).replace(/\/+$/, "");
      break;
    }
  }
  return s;
}

function unwrapData<T>(json: Record<string, unknown>): T {
  const data = json.data;
  return (data !== undefined ? data : json) as T;
}

export function createMachineAuthnClient(options: MachineAuthnClientOptions) {
  const fetchImpl = options.fetch ?? globalThis.fetch;
  const origin = normalizeOrigin(options.baseUrl);
  const apiBase = `${origin}/api/v1`;

  async function request<T>(
    method: "GET" | "POST",
    path: string,
    body?: unknown,
    query?: Record<string, string | undefined>,
    withAuth = true,
  ): Promise<T> {
    const url = new URL(`${apiBase}${path}`);
    if (query) {
      for (const [key, value] of Object.entries(query)) {
        if (value !== undefined) url.searchParams.set(key, value);
      }
    }
    const headers = new Headers(options.headers);
    if (body !== undefined) headers.set("content-type", "application/json");
    if (withAuth && options.authorization) {
      const raw = options.authorization.trim();
      headers.set(
        "authorization",
        raw.toLowerCase().startsWith("bearer ") ? raw : `Bearer ${raw}`,
      );
    }
    const res = await fetchImpl(url, {
      method,
      headers,
      ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
    });
    if (!res.ok) {
      const text = await res.text();
      throw new Error(`Machine AuthN request failed (${res.status}): ${text}`);
    }
    const json = (await res.json()) as Record<string, unknown>;
    return unwrapData<T>(json);
  }

  return {
    register(body: Record<string, unknown>) {
      return request<Record<string, unknown>>(
        "POST",
        `${MACHINE_AUTHN}/register`,
        body,
      );
    },
    enrollCreate(body: Record<string, unknown>) {
      return request<Record<string, unknown>>(
        "POST",
        `${MACHINE_AUTHN}/enroll-create`,
        body,
      );
    },
    enrollApprove(body: Record<string, unknown>) {
      return request<Record<string, unknown>>(
        "POST",
        `${MACHINE_AUTHN}/enroll-approve`,
        body,
      );
    },
    enrollPull(body: { pullToken: string }) {
      return request<Record<string, unknown>>(
        "POST",
        `${MACHINE_AUTHN}/enroll-pull`,
        body,
        undefined,
        false,
      );
    },
    enrollInvite(body: Record<string, unknown>) {
      return request<Record<string, unknown>>(
        "POST",
        `${MACHINE_AUTHN}/enroll-invite`,
        body,
      );
    },
    getEnrollInvite(query: { payingPartyId: string; inviteToken: string }) {
      return request<Record<string, unknown>>(
        "GET",
        `${MACHINE_AUTHN}/enroll-invite`,
        undefined,
        query,
        false,
      );
    },
    issueDelegate(body: Record<string, unknown>) {
      return request<Record<string, unknown>>(
        "POST",
        `${MACHINE_AUTHN}/issue-delegate`,
        body,
      );
    },
    assertSubset(body: Record<string, unknown>) {
      return request<{ ok: boolean }>(
        "POST",
        `${MACHINE_AUTHN}/assert-subset`,
        body,
      );
    },
    platformRoot() {
      return request<Record<string, unknown>>(
        "GET",
        `${MACHINE_AUTHN}/platform-root`,
        undefined,
        undefined,
        false,
      );
    },
    credentialStatus(query: { ski: string }) {
      return request<Record<string, unknown>>(
        "GET",
        `${MACHINE_AUTHN}/credential-status`,
        undefined,
        query,
      );
    },
    /** @x-sdk-forward — may 404 on older servers */
    enrollList(query: { entityId: string; status?: string }) {
      return request<Record<string, unknown>>(
        "GET",
        `${MACHINE_AUTHN}/enroll-list`,
        undefined,
        query,
      );
    },
    /** @x-sdk-forward — may 404 on older servers */
    machineRenew(body: Record<string, unknown>) {
      return request<Record<string, unknown>>(
        "POST",
        `${MACHINE_AUTHN}/machine-renew`,
        body,
      );
    },
  };
}

export type MachineAuthnClient = ReturnType<typeof createMachineAuthnClient>;
