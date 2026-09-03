import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { createMachineAuthnClient } from "./machine-authn.js";

describe("createMachineAuthnClient", () => {
  it("posts enroll-create under /api/v1/machine-authn", async () => {
    let capturedUrl = "";
    const client = createMachineAuthnClient({
      baseUrl: "https://billing.example.com",
      authorization: "token",
      fetch: async (input, init) => {
        capturedUrl = String(input);
        assert.equal(init?.method, "POST");
        return new Response(
          JSON.stringify({
            data: { enrollId: "1", pullToken: "ptok", status: "pending" },
          }),
          { status: 201 },
        );
      },
    });

    const res = await client.enrollCreate({
      payingPartyId: "1",
      memberId: "m",
      csrPem: "csr",
    });
    assert.equal(
      capturedUrl,
      "https://billing.example.com/api/v1/machine-authn/enroll-create",
    );
    assert.equal(res.pullToken, "ptok");
  });
});
