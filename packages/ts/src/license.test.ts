import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { normalizeApiBaseUrl } from "./config.ts";
import { parseLicenseClaims } from "./license.ts";

const here = dirname(fileURLToPath(import.meta.url));
const fixturePath = join(
  here,
  "../../../conformance/fixtures/license_payload_v1.json",
);

test("normalizeApiBaseUrl strips /api/v1", () => {
  assert.equal(
    normalizeApiBaseUrl("https://billing.example.com/api/v1/"),
    "https://billing.example.com",
  );
});

test("fixture claims parse (conformance)", () => {
  const raw = JSON.parse(readFileSync(fixturePath, "utf8")) as {
    claims: unknown;
  };
  const payload = parseLicenseClaims(raw.claims);
  assert.equal(payload.payloadVersion, 1);
  assert.equal(payload.payingParty.id, "pp_test_1");
  assert.equal(payload.subscriptions.length, 2);
  assert.ok(payload.subscriptions.some((s) => s.addonCode === "ai_assistant"));
});
