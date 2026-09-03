import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { normalizeApiBaseUrl } from "./config.ts";
import { licenseEntitlements, parseLicenseClaims } from "./license.ts";

const here = dirname(fileURLToPath(import.meta.url));

test("normalizeApiBaseUrl strips /api/v1", () => {
  assert.equal(
    normalizeApiBaseUrl("https://billing.example.com/api/v1/"),
    "https://billing.example.com",
  );
});

test("fixture claims parse v1 (conformance)", () => {
  const fixturePath = join(
    here,
    "../../../../../../conformance/fixtures/license_payload_v1.json",
  );
  const raw = JSON.parse(readFileSync(fixturePath, "utf8")) as {
    claims: unknown;
  };
  const payload = parseLicenseClaims(raw.claims);
  assert.equal(payload.payloadVersion, 1);
  assert.equal(payload.payingParty.id, "pp_test_1");
  assert.equal(payload.subscriptions.length, 2);
  assert.ok(payload.subscriptions.some((s) => s.addonCode === "ai_assistant"));
});

test("fixture claims parse v3 entitlements (conformance)", () => {
  const fixturePath = join(
    here,
    "../../../../../../conformance/fixtures/license_payload_v3.json",
  );
  const raw = JSON.parse(readFileSync(fixturePath, "utf8")) as {
    claims: unknown;
  };
  const payload = parseLicenseClaims(raw.claims);
  assert.equal(payload.payloadVersion, 3);
  assert.equal(payload.subscriptions[0]?.quantity, 2);
  const e = licenseEntitlements(payload, 1_700_000_000);
  assert.equal(e.maxDevices, 10);
  assert.equal(e.hasAddon("scomm_connector"), true);
  assert.equal(e.hasOffering("scomm_connector_5"), true);
  assert.equal(e.resourceForProduct("prod_mail", "max_devices"), 10);
  assert.equal(e.byProduct.prod_mail?.max_devices, 10);
});

test("catalog intersection fails closed", () => {
  const fixturePath = join(
    here,
    "../../../../../../conformance/fixtures/license_payload_v3.json",
  );
  const raw = JSON.parse(readFileSync(fixturePath, "utf8")) as {
    claims: unknown;
  };
  const payload = parseLicenseClaims(raw.claims);
  const open = licenseEntitlements(payload, 1_700_000_000);
  assert.equal(open.hasProduct("prod_mail"), true);
  assert.equal(open.hasOffering("scomm_connector_5"), true);

  const gated = licenseEntitlements(payload, 1_700_000_000, {
    productIds: ["prod_mail"],
    offeringCodes: ["scomm_connector_5"],
    addonCodes: ["scomm_connector"],
  });
  assert.equal(gated.hasProduct("prod_mail"), true);
  assert.equal(gated.hasOffering("scomm_connector_5"), true);
  assert.equal(gated.hasAddon("scomm_connector"), true);
  assert.equal(gated.hasProduct("unknown_product"), false);
  assert.equal(gated.hasOffering("unknown_offering"), false);
  assert.equal(gated.hasAddon("unknown_addon"), false);

  const otherApp = licenseEntitlements(payload, 1_700_000_000, {
    productIds: ["other_product"],
    offeringCodes: ["other_offering"],
    addonCodes: ["other_addon"],
  });
  assert.equal(otherApp.hasProduct("prod_mail"), false);
  assert.equal(otherApp.hasOffering("scomm_connector_5"), false);
  assert.equal(otherApp.hasAddon("scomm_connector"), false);
});
