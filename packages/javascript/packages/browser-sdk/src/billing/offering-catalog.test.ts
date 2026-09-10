import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { TwoKeyError } from "./errors.ts";
import {
  catalogForHost,
  catalogKnowsAddon,
  catalogKnowsProduct,
  parseHostsCatalog,
} from "./offering-catalog.ts";

const here = dirname(fileURLToPath(import.meta.url));
const hostsPath = join(
  here,
  "../../../../../../conformance/fixtures/scomm_host_catalogs.json",
);

test("catalogForHost slices baked hosts.json", () => {
  const hosts = JSON.parse(readFileSync(hostsPath, "utf8"));
  const office = catalogForHost(hosts, "office");
  assert.deepEqual(office.productNames, ["Scomm"]);
  assert.ok(office.offeringCodes.includes("pgp"));
  assert.ok(office.addonCodes.includes("pgp"));
  assert.equal(office.offeringCodes.includes("linux"), false);
  assert.equal(catalogKnowsProduct(office, "Scomm"), true);
  assert.equal(catalogKnowsProduct(office, "42"), false);
  assert.equal(catalogKnowsAddon(office, "linux"), false);

  const desktop = catalogForHost(hosts, "scommDesktop");
  assert.equal(desktop.offeringCodes.includes("pgp"), false);
  assert.equal(desktop.offeringCodes.includes("linux"), false);
  assert.ok(desktop.offeringCodes.includes("accent_color"));

  const linux = catalogForHost(hosts, "scommLinux");
  assert.ok(linux.offeringCodes.includes("linux"));
  assert.equal(linux.offeringCodes.includes("pgp"), false);
});

test("catalogForHost rejects unknown host keys", () => {
  const hosts = parseHostsCatalog(JSON.parse(readFileSync(hostsPath, "utf8")));
  assert.throws(() => catalogForHost(hosts, "missing"), (err: unknown) => {
    assert.ok(err instanceof TwoKeyError);
    assert.equal(err.code, "config");
    return true;
  });
});
