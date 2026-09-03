import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { parsePlan } from "./catalog.js";
import { portalHandoffUrl } from "../auth/auth.js";

describe("parsePlan", () => {
  it("accepts camelCase and snake_case", () => {
    const p = parsePlan({
      id: 1,
      product_id: 9,
      name: "Pro",
      billing_interval: "monthly",
      base_price: 10,
      currency: "USD",
      addon_code: "ai",
      is_active: true,
    });
    assert.equal(p.productId, 9);
    assert.equal(p.billingInterval, "monthly");
    assert.equal(p.addonCode, "ai");
  });
});

describe("portalHandoffUrl", () => {
  it("joins redirect + ott", () => {
    const url = portalHandoffUrl(
      { apiBaseUrl: "https://billing.example.com", publicKeyPem: "x", storagePrefix: "t" },
      { redirectPath: "/subscriptions", ott: "abc" },
    );
    assert.match(url, /\/auth\/handoff/);
    assert.match(url, /ott=abc/);
    assert.match(url, /redirect=%2Fsubscriptions/);
  });
});
