import assert from "node:assert/strict";
import { test } from "node:test";
import {
  acquireApiToken,
  acquireUsingPartyApiToken,
  exchangeOneTimeToken,
} from "./auth.ts";
import { officeSocialStartUrl } from "./portal.ts";
import { TwoKeyError } from "../billing/errors.ts";

const cfg = {
  apiBaseUrl: "https://billing.example.com",
  publicKeyPem: "x",
  storagePrefix: "auth-ott-test",
};

test("officeSocialStartUrl points at billing-hosted start page", () => {
  const url = officeSocialStartUrl(cfg, {
    provider: "google",
    returnUrl: "https://localhost:5173/auth-callback.html",
    waitId: "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  });
  assert.match(url, /^https:\/\/billing\.example\.com\/oauth\/office-start\.html\?/);
  assert.match(url, /provider=google/);
  assert.match(url, /return=https%3A%2F%2Flocalhost%3A5173%2Fauth-callback\.html/);
  assert.match(url, /wait=7c9e6679-7425-40de-944b-e07fc1f90ae7/);
});

test("exchangeOneTimeToken verifies OTT then mints JWT with bearer", async () => {
  const calls: string[] = [];
  const fetchImpl: typeof fetch = async (input, init) => {
    const url = String(input);
    calls.push(`${init?.method ?? "GET"} ${url}`);
    if (url.endsWith("/one-time-token/verify")) {
      assert.equal(init?.method, "POST");
      assert.equal(JSON.parse(String(init?.body)).token, "ott-1");
      return new Response(JSON.stringify({ session: { token: "ba-session" } }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    assert.match(url, /\/api\/auth\/token$/);
    const auth = new Headers(init?.headers).get("Authorization");
    assert.equal(auth, "Bearer ba-session");
    return new Response(JSON.stringify({ token: "jwt-1" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  };

  const result = await exchangeOneTimeToken(cfg, "ott-1", { fetchImpl });
  assert.equal(result.token, "jwt-1");
  assert.deepEqual(calls, [
    "POST https://billing.example.com/api/auth/one-time-token/verify",
    "GET https://billing.example.com/api/auth/token",
  ]);
});

test("exchangeOneTimeToken maps 401", async () => {
  const fetchImpl: typeof fetch = async () =>
    new Response(JSON.stringify({ message: "bad ott" }), { status: 401 });
  await assert.rejects(
    () => exchangeOneTimeToken(cfg, "bad", { fetchImpl }),
    (e: unknown) => e instanceof TwoKeyError && e.code === "unauthorized",
  );
});

test("acquireApiToken sends stored-style session bearer when provided", async () => {
  const fetchImpl: typeof fetch = async (_input, init) => {
    assert.equal(new Headers(init?.headers).get("Authorization"), "Bearer sess");
    return new Response(JSON.stringify({ token: "jwt-2" }), { status: 200 });
  };
  const result = await acquireApiToken(cfg, { fetchImpl, sessionToken: "sess" });
  assert.equal(result.token, "jwt-2");
});

test("acquireApiToken maps 403 ORG_SLUG_REQUIRED to orgPickRequired", async () => {
  const fetchImpl: typeof fetch = async () =>
    new Response(JSON.stringify({ code: "ORG_SLUG_REQUIRED", message: "Bind" }), {
      status: 403,
    });
  const result = await acquireApiToken(cfg, { fetchImpl, sessionToken: "sess" });
  assert.equal(result.token, "");
  assert.equal(result.orgPickRequired, true);
});

test("acquireUsingPartyApiToken binds me then remints", async () => {
  const calls: string[] = [];
  const fetchImpl: typeof fetch = async (input, init) => {
    const url = String(input);
    calls.push(`${init?.method ?? "GET"} ${url}`);
    if (url.endsWith("/organization/bind")) {
      assert.equal(JSON.parse(String(init?.body)).slug, "me");
      return new Response(
        JSON.stringify({
          organizationId: "org-1",
          slug: "me",
          name: "Ada's Organization",
          role: "owner",
        }),
        { status: 200 },
      );
    }
    if (calls.filter((c) => c.startsWith("GET ") && c.endsWith("/token")).length === 1) {
      return new Response(JSON.stringify({ code: "ORG_SLUG_REQUIRED" }), { status: 403 });
    }
    return new Response(JSON.stringify({ token: "jwt-personal" }), { status: 200 });
  };

  const result = await acquireUsingPartyApiToken(cfg, { fetchImpl, sessionToken: "sess" });
  assert.equal(result.token, "jwt-personal");
  assert.deepEqual(calls, [
    "GET https://billing.example.com/api/auth/token",
    "POST https://billing.example.com/api/auth/organization/bind",
    "GET https://billing.example.com/api/auth/token",
  ]);
});

test("exchangeOneTimeToken usingParty auto-binds personal org", async () => {
  const calls: string[] = [];
  const fetchImpl: typeof fetch = async (input, init) => {
    const url = String(input);
    calls.push(`${init?.method ?? "GET"} ${url}`);
    if (url.endsWith("/one-time-token/verify")) {
      return new Response(JSON.stringify({ session: { token: "ba-session" } }), {
        status: 200,
      });
    }
    if (url.endsWith("/organization/bind")) {
      return new Response(
        JSON.stringify({
          organizationId: "org-1",
          slug: "me",
          name: "Personal",
          role: "owner",
        }),
        { status: 200 },
      );
    }
    if (calls.filter((c) => c.startsWith("GET ") && c.endsWith("/token")).length === 1) {
      return new Response(JSON.stringify({ code: "ORG_SLUG_REQUIRED" }), { status: 403 });
    }
    return new Response(JSON.stringify({ token: "jwt-up" }), { status: 200 });
  };

  const result = await exchangeOneTimeToken(cfg, "ott-1", { fetchImpl, usingParty: true });
  assert.equal(result.token, "jwt-up");
  assert.equal(calls[0], "POST https://billing.example.com/api/auth/one-time-token/verify");
  assert.ok(calls.includes("POST https://billing.example.com/api/auth/organization/bind"));
});
