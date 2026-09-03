import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { createAgentTokenClient } from "./agent-token.js";

describe("createAgentTokenClient", () => {
  it("posts mint to /api/auth/agent/token", async () => {
    let capturedUrl = "";
    const client = createAgentTokenClient({
      authOrigin: "https://billing.example.com/api/v1",
      fetch: async (input, init) => {
        capturedUrl = String(input);
        assert.equal(init?.method, "POST");
        return new Response(JSON.stringify({ data: { token: "jwt", expiresIn: 60 } }), {
          status: 200,
        });
      },
    });

    const res = await client.mintAgentToken({
      credential: { v: 1 },
      proof: { ts: 1, signature: "sig" },
      targetIdentity: "cam1.acme.idr.to",
    });
    assert.equal(capturedUrl, "https://billing.example.com/api/auth/agent/token");
    assert.equal(res.token, "jwt");
    assert.equal(res.expiresIn, 60);
  });
});
