import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { DeviceEnrollRequest, EnrollCreateResult } from "@2key/dp-spec";
import { createAdminClient, createEnrollClient } from "./admin.js";

describe("createEnrollClient", () => {
  it("generates a device key+CSR, posts enroll-create, and returns local material", async () => {
    let capturedUrl = "";
    let capturedBody: DeviceEnrollRequest | undefined;

    const fetchImpl: typeof fetch = async (url, init) => {
      capturedUrl = String(url);
      capturedBody = JSON.parse(String(init?.body)) as DeviceEnrollRequest;
      const result: EnrollCreateResult = {
        enrollId: "enr_1",
        pullToken: "pull_1",
        subjectSki: capturedBody.subjectSki ?? "",
        kind: "machine_target",
        status: "pending",
      };
      return new Response(JSON.stringify(result), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    };

    const client = createEnrollClient({
      baseURL: "https://auth.example.com/api/v1/",
      fetch: fetchImpl,
    });

    const enrolled = await client.enroll({
      entityId: "acme.example",
      host: "db1--acme.example",
    });

    assert.ok(capturedBody);
    assert.match(capturedUrl, /\/machine-authn\/enroll-create$/);
    assert.equal(capturedBody?.entityId, "acme.example");
    assert.equal(capturedBody?.host, "db1--acme.example");
    assert.equal(capturedBody?.subjectSki, enrolled.ski);
    assert.match(capturedBody?.csrPem ?? "", /BEGIN CERTIFICATE REQUEST/);
    assert.equal(enrolled.ski.length, 43);
    assert.equal(typeof enrolled.privateJwk.d, "string");
    assert.equal(enrolled.enrollment.status, "pending");
    assert.equal(enrolled.enrollment.enrollId, "enr_1");
    assert.equal(enrolled.identity, undefined);
  });
});

describe("createAdminClient lifecycle", () => {
  it("forwards live Machine AuthN endpoints and throws on removed ones", async () => {
    const seen: { method: string; url: string }[] = [];
    const fetchImpl: typeof fetch = async (url, init) => {
      seen.push({
        method: String(init?.method ?? "GET"),
        url: String(url),
      });
      return new Response(JSON.stringify({ data: { ok: true } }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    };

    const admin = createAdminClient({
      baseURL: "https://auth.example.com/api/v1/",
      fetch: fetchImpl,
    });

    await admin.credentialStatus({ ski: "abc" });
    await admin.enrollList({ entityId: "acme.example" });
    await admin.machineRenew({
      ski: "abc",
      csrPem: "csr",
      leafPem: "leaf",
      chainPem: "chain",
      credential: { version: 1 } as never,
      issuerSki: "iss",
    });
    await admin.issueDelegate({
      entityId: "acme.example",
      kind: "interim_admin",
      issuerPrivateJwk: { kty: "OKP" },
      issuerSki: "iss",
    });
    await admin.platformRoot();

    const paths = seen.map((s) => `${s.method} ${new URL(s.url).pathname}`);
    assert.deepEqual(paths, [
      "GET /api/v1/machine-authn/credential-status",
      "GET /api/v1/machine-authn/enroll-list",
      "POST /api/v1/machine-authn/machine-renew",
      "POST /api/v1/machine-authn/issue-delegate",
      "GET /api/v1/machine-authn/platform-root",
    ]);
    assert.equal(new URL(seen[0]!.url).searchParams.get("ski"), "abc");

    assert.throws(
      () => admin.credentialRevoke({ ski: "abc", reason: "key_compromise" }),
      /credential-revoke not on billing server/,
    );
    assert.throws(
      () =>
        admin.issueMachine({
          entityId: "acme.example",
          host: "db1--acme.example",
          issuerPrivateJwk: { kty: "OKP" },
          issuerSki: "iss",
        }),
      /issue-machine removed/,
    );
  });
});
