import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { webcrypto } from "node:crypto";
import { createBillingClient } from "./client.ts";
import { TwoKeyError } from "./errors.ts";
import { memorySessionStore } from "./session.ts";

if (!globalThis.crypto) {
  (globalThis as { crypto: Crypto }).crypto = webcrypto as unknown as Crypto;
}

const here = dirname(fileURLToPath(import.meta.url));
const fixturePath = join(
  here,
  "../../../../../../conformance/fixtures/license_payload_v3.json",
);

function b64url(data: Uint8Array): string {
  let s = Buffer.from(data).toString("base64");
  return s.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

async function generateEs256PemAndSign(claims: object): Promise<{
  pem: string;
  jwt: string;
}> {
  const pair = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  );
  const spki = new Uint8Array(await crypto.subtle.exportKey("spki", pair.publicKey));
  const pem =
    "-----BEGIN PUBLIC KEY-----\n" +
    Buffer.from(spki).toString("base64").match(/.{1,64}/g)!.join("\n") +
    "\n-----END PUBLIC KEY-----\n";

  const header = { alg: "ES256", typ: "JWT" };
  const h = b64url(new TextEncoder().encode(JSON.stringify(header)));
  const p = b64url(new TextEncoder().encode(JSON.stringify(claims)));
  const input = `${h}.${p}`;
  const sig = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      pair.privateKey,
      new TextEncoder().encode(input),
    ),
  );
  return { pem, jwt: `${input}.${b64url(sig)}` };
}

function jsonResponse(status: number, body: unknown, headers?: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...headers },
  });
}

test("createBillingClient restore + catalog gates", async () => {
  const raw = JSON.parse(readFileSync(fixturePath, "utf8")) as {
    claims: Record<string, unknown>;
  };
  const now = Math.floor(Date.now() / 1000);
  const claims = { ...raw.claims, iat: now, exp: now + 3600 };
  const { pem, jwt } = await generateEs256PemAndSign(claims);
  const store = memorySessionStore();
  const billing = createBillingClient(
    {
      apiBaseUrl: "https://billing.example.com",
      publicKeyPem: pem,
      storagePrefix: "office-test",
      catalog: {
        productIds: ["prod_mail"],
        offeringCodes: ["scomm_connector_5"],
        addonCodes: ["scomm_connector"],
      },
    },
    { store },
  );
  await billing.pasteLicense(jwt);
  const restored = await billing.restore();
  assert.equal(restored?.payingParty.id, "pp_test_1");
  assert.equal(billing.hasProduct("prod_mail"), true);
  assert.equal(billing.hasOffering("scomm_connector_5"), true);
  assert.equal(billing.hasAddon("scomm_connector"), true);
  assert.equal(billing.hasProduct("unknown"), false);
});

test("syncLicense binds device then fetches license", async () => {
  const raw = JSON.parse(readFileSync(fixturePath, "utf8")) as {
    claims: Record<string, unknown>;
  };
  const now = Math.floor(Date.now() / 1000);
  const claims = { ...raw.claims, iat: now, exp: now + 3600 };
  const { pem, jwt } = await generateEs256PemAndSign(claims);

  const fetchImpl: typeof fetch = async (input, init) => {
    const url = String(input);
    const method = (init?.method ?? "GET").toUpperCase();
    if (method === "POST" && url.includes("/api/v1/license/devices")) {
      return jsonResponse(200, {
        success: true,
        data: { device: { ski: "x" }, seat: { maxDevices: 5 } },
      });
    }
    if (method === "GET" && url.includes("/api/v1/license") && !url.includes("/devices")) {
      return jsonResponse(200, { success: true, data: { signedToken: jwt } }, { etag: '"abc"' });
    }
    return jsonResponse(404, { success: false, error: "not found" });
  };

  const billing = createBillingClient(
    {
      apiBaseUrl: "https://billing.example.com",
      publicKeyPem: pem,
      storagePrefix: "office-sync",
    },
    { store: memorySessionStore(), fetchImpl },
  );

  const payload = await billing.syncLicense({ accessToken: "tok" });
  assert.equal(payload.payingParty.id, "pp_test_1");
  const device = await billing.ensureDeviceId();
  assert.ok(device.ski);
});

test("bindLicenseDevice maps HTTP 409 to conflict", async () => {
  const fetchImpl: typeof fetch = async () =>
    jsonResponse(409, {
      success: false,
      error: "Device limit reached",
      code: "DEVICE_LIMIT_REACHED",
    });
  const billing = createBillingClient(
    {
      apiBaseUrl: "https://billing.example.com",
      publicKeyPem: "x",
      storagePrefix: "conflict-test",
    },
    { store: memorySessionStore(), fetchImpl },
  );
  await assert.rejects(
    () =>
      billing.api.bindLicenseDevice({
        accessToken: "tok",
        publicJwk: { kty: "OKP", crv: "Ed25519", x: "aa" },
      }),
    (e: unknown) => e instanceof TwoKeyError && e.code === "conflict",
  );
});
