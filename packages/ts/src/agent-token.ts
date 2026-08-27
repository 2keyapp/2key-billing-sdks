export type AgentTokenClientOptions = {
  readonly authOrigin: string;
  readonly fetch?: typeof fetch;
};

export type AgentTokenMintRequest = {
  readonly credential: Record<string, unknown>;
  readonly proof: { ts: number; signature: string };
  readonly targetIdentity: string;
};

export type AgentTokenMintResponse = {
  readonly token: string;
  readonly expiresIn: number;
  readonly token_type?: string;
};

function normalizeAuthOrigin(input: string): string {
  let s = input.trim().replace(/\/+$/, "");
  for (const suffix of ["/api/v1", "/api/billing"]) {
    if (s.toLowerCase().endsWith(suffix)) {
      s = s.slice(0, -suffix.length).replace(/\/+$/, "");
      break;
    }
  }
  return s;
}

export function createAgentTokenClient(options: AgentTokenClientOptions) {
  const fetchImpl = options.fetch ?? globalThis.fetch;
  const origin = normalizeAuthOrigin(options.authOrigin);

  return {
    async mintAgentToken(
      body: AgentTokenMintRequest,
    ): Promise<AgentTokenMintResponse> {
      const res = await fetchImpl(`${origin}/api/auth/agent/token`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
      });
      if (!res.ok) {
        const text = await res.text();
        throw new Error(`Agent token mint failed (${res.status}): ${text}`);
      }
      const json = (await res.json()) as Record<string, unknown>;
      const data = (json.data ?? json) as AgentTokenMintResponse;
      return data;
    },
  };
}

export type AgentTokenClient = ReturnType<typeof createAgentTokenClient>;
