import assert from "node:assert/strict";
import { test } from "node:test";
import { fetchOAuthProviders, signInWithEmail, signUpWithEmail } from "./email.ts";
import { TwoKeyError } from "../billing/errors.ts";

const cfg = {
  apiBaseUrl: "https://billing.example.com",
  publicKeyPem: "x",
  storagePrefix: "auth-test",
};

test("signInWithEmail posts email/password", async () => {
  const fetchImpl: typeof fetch = async (input, init) => {
    assert.match(String(input), /\/api\/auth\/sign-in\/email$/);
    assert.equal(init?.method, "POST");
    const body = JSON.parse(String(init?.body));
    assert.equal(body.email, "a@b.com");
    return new Response(JSON.stringify({ user: { id: "u1", email: "a@b.com" } }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  };
  const result = await signInWithEmail(cfg, {
    email: "a@b.com",
    password: "secret",
    fetchImpl,
  });
  assert.equal(result.user.id, "u1");
});

test("signUpWithEmail posts name", async () => {
  const fetchImpl: typeof fetch = async (input, init) => {
    assert.match(String(input), /\/api\/auth\/sign-up\/email$/);
    const body = JSON.parse(String(init?.body));
    assert.equal(body.name, "Ada");
    return new Response(JSON.stringify({ user: { id: "u2", name: "Ada" } }), {
      status: 201,
      headers: { "Content-Type": "application/json" },
    });
  };
  const result = await signUpWithEmail(cfg, {
    email: "ada@b.com",
    password: "secret",
    name: "Ada",
    fetchImpl,
  });
  assert.equal(result.user.name, "Ada");
});

test("signInWithEmail maps 401", async () => {
  const fetchImpl: typeof fetch = async () =>
    new Response(JSON.stringify({ message: "Invalid password" }), { status: 401 });
  await assert.rejects(
    () => signInWithEmail(cfg, { email: "a@b.com", password: "bad", fetchImpl }),
    (e: unknown) => e instanceof TwoKeyError && e.code === "unauthorized",
  );
});

test("fetchOAuthProviders parses enabled providers", async () => {
  const fetchImpl: typeof fetch = async (input) => {
    assert.match(String(input), /\/api\/auth\/\.well-known\/oauth-providers$/);
    return new Response(
      JSON.stringify({
        issuer: "https://billing.example.com/api/auth",
        providers: [
          { id: "google", enabled: true, redirectUri: "https://billing.example.com/api/auth/callback/google" },
          { id: "email", enabled: true },
        ],
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  };
  const doc = await fetchOAuthProviders(cfg, { fetchImpl });
  assert.equal(doc.issuer, "https://billing.example.com/api/auth");
  assert.equal(doc.providers.length, 2);
  assert.equal(doc.providers[0]?.id, "google");
});
