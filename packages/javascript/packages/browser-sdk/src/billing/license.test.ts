import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { normalizeApiBaseUrl } from "./config.ts";
import { licenseEntitlements, parseLicenseClaims } from "./license.ts";
import { catalogForHost } from "./offering-catalog.ts";

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
  assert.ok(e.addonCodes.includes("scomm_connector"));
  assert.ok(e.offeringCodes.includes("scomm_connector_5"));
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

test("Scomm host catalogs split pgp / pqc / linux on one JWT", () => {
  const splitPath = join(
    here,
    "../../../../../../conformance/fixtures/license_payload_scomm_split.json",
  );
  const catalogsPath = join(
    here,
    "../../../../../../conformance/fixtures/scomm_host_catalogs.json",
  );
  const split = JSON.parse(readFileSync(splitPath, "utf8")) as {
    claims: unknown;
  };
  const hosts = JSON.parse(readFileSync(catalogsPath, "utf8"));
  const payload = parseLicenseClaims(split.claims);

  const open = licenseEntitlements(payload, 1_700_000_000);
  assert.equal(open.hasAddon("linux"), true);
  assert.equal(open.hasAddon("pgp"), true);
  assert.equal(open.hasAddon("pqc"), true);
  assert.equal(open.hasProduct("prod_mail"), true);

  const email = licenseEntitlements(payload, 1_700_000_000, catalogForHost(hosts, "scommDesktop"));
  assert.equal(email.hasProduct("Scomm"), true);
  assert.equal(email.hasProduct("prod_mail"), false);
  assert.equal(email.resourceForProduct("Scomm", "max_devices"), 5);
  assert.equal(email.resourceInt("max_devices"), 5);
  assert.equal(email.hasAddon("pqc"), true);
  assert.equal(email.hasAddon("ai_assistant"), true);
  assert.equal(email.hasAddon("pgp"), false);
  assert.equal(email.hasAddon("linux"), false);

  const emailLinux = licenseEntitlements(
    payload,
    1_700_000_000,
    catalogForHost(hosts, "scommLinux"),
  );
  assert.equal(emailLinux.hasAddon("linux"), true);
  assert.equal(emailLinux.hasAddon("pqc"), true);
  assert.equal(emailLinux.hasAddon("pgp"), false);

  const office = licenseEntitlements(payload, 1_700_000_000, catalogForHost(hosts, "office"));
  assert.equal(office.hasProduct("Scomm"), true);
  assert.equal(office.hasAddon("pgp"), true);
  assert.equal(office.hasAddon("pqc"), true);
  assert.equal(office.hasAddon("ai_assistant"), true);
  assert.equal(office.hasAddon("linux"), false);
  assert.equal(office.hasAddon("accent_color"), false);
  assert.equal(
    office.subscriptions.some((sub) => sub.addonCode === "linux"),
    false,
  );
  assert.equal(
    office.subscriptions.some((sub) => sub.addonCode === "ai_assistant"),
    true,
  );
});

test("catalog productNames remap serial JWT product_id without double-counting", () => {
  const payload = parseLicenseClaims({
    payload_version: 3,
    paying_party: {
      id: "pp1",
      identity_provider: "google",
      identity_subject: "sub",
      billing_email: "a@b.com",
    },
    subscriptions: [
      {
        subscription_id: "s1",
        plan_id: "1",
        plan_name: "A",
        product_id: "42",
        product_name: "Scomm",
        subscription_status: "active",
        valid_until: 4102444800,
        quantity: 1,
        offerings: [
          {
            offering_id: "o1",
            offering_code: "pqc",
            product_id: "42",
            product_name: "Scomm",
            units: 1,
            resources: { max_devices: 5, addon_code: "pqc" },
          },
        ],
      },
    ],
    entitlements: {
      by_product: { "42": { max_devices: 5 } },
      addons: ["pqc"],
      by_offering_code: { pqc: { addon_code: "pqc" } },
    },
  });
  const gated = licenseEntitlements(payload, 1_700_000_000, {
    productNames: ["Scomm"],
    offeringCodes: ["pqc"],
    addonCodes: ["pqc"],
  });
  assert.equal(gated.hasProduct("Scomm"), true);
  assert.equal(gated.hasProduct("42"), false);
  assert.equal(gated.resourceForProduct("Scomm", "max_devices"), 5);
  assert.equal(gated.resourceInt("max_devices"), 5);
});
