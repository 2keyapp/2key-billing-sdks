import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import assert from "node:assert/strict";
import { test } from "node:test";
import { webcrypto } from "node:crypto";
import { verifyLicenseJwt } from "./verify.ts";
import { BrowserSessionManager, memorySessionStore } from "./session.ts";
import { portalPathUrl, shopUrl } from "./portal.ts";
import { TwoKeyError } from "./errors.ts";

// Node <19 may need explicit crypto; Node 20+ has global crypto.
if (!globalThis.crypto) {
  (globalThis as { crypto: Crypto }).crypto = webcrypto as unknown as Crypto;
}

const here = dirname(fileURLToPath(import.meta.url));
const fixturePath = join(
  here,
  "../../../conformance/fixtures/license_payload_v1.json",
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

test("verifyLicenseJwt accepts valid ES256 token", async () => {
  const raw = JSON.parse(readFileSync(fixturePath, "utf8")) as {
    claims: Record<string, unknown>;
  };
  const now = Math.floor(Date.now() / 1000);
  const claims = { ...raw.claims, iat: now, exp: now + 3600 };
  const { pem, jwt } = await generateEs256PemAndSign(claims);
  const payload = await verifyLicenseJwt(jwt, pem, now);
  assert.equal(payload.payingParty.id, "pp_test_1");
});

test("verifyLicenseJwt rejects wrong key", async () => {
  const raw = JSON.parse(readFileSync(fixturePath, "utf8")) as {
    claims: Record<string, unknown>;
  };
  const now = Math.floor(Date.now() / 1000);
  const claims = { ...raw.claims, iat: now, exp: now + 3600 };
  const { jwt } = await generateEs256PemAndSign(claims);
  const other = await generateEs256PemAndSign(claims);
  await assert.rejects(
    () => verifyLicenseJwt(jwt, other.pem, now),
    (e: unknown) => e instanceof TwoKeyError && e.code === "license_invalid",
  );
});

test("session roundtrip", async () => {
  const mgr = new BrowserSessionManager(
    {
      apiBaseUrl: "https://billing.example.com",
      publicKeyPem: "-----BEGIN PUBLIC KEY-----\nMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE\n-----END PUBLIC KEY-----",
      storagePrefix: "billing_test",
    },
    memorySessionStore(),
  );
  // validateConfig requires non-empty PEM — use a real-looking minimal? validate only checks non-empty.
  await mgr.save({ accountKey: "u1", accessToken: "tok" });
  const loaded = await mgr.load("u1");
  assert.equal(loaded?.accessToken, "tok");
  await mgr.clear("u1");
  assert.equal(await mgr.load("u1"), null);
});

test("portal urls", () => {
  const cfg = {
    apiBaseUrl: "https://billing.example.com",
    publicKeyPem: "x",
    storagePrefix: "app",
    shopPath: "/shop",
  };
  assert.equal(shopUrl(cfg), "https://billing.example.com/shop");
  assert.equal(
    portalPathUrl(cfg, "/subscriptions"),
    "https://billing.example.com/subscriptions",
  );
});
