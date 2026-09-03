import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  CATALOG_SEED,
  ENTITLEMENT_ACTION_MAP,
  OS20_PLAN_CODES,
  SERVICE_ID,
} from "./index.js";

describe("@2key/catalog-os20", () => {
  it("seeds serviceId os20 with actions, dimensions, and profiles", () => {
    assert.equal(SERVICE_ID, "os20");
    assert.equal(CATALOG_SEED.serviceId, "os20");
    assert.ok(CATALOG_SEED.actions.length > 20);
    const resource = CATALOG_SEED.scopeDimensions.find(
      (d) => d.dimension === "resource",
    );
    assert.equal(resource?.algebra, "path_prefix");
    const version = CATALOG_SEED.scopeDimensions.find(
      (d) => d.dimension === "version",
    );
    assert.equal(version?.algebra, "semver");
    assert.ok(
      CATALOG_SEED.profiles.some((p) => p.profile === "organization_owner"),
    );
    assert.ok(
      CATALOG_SEED.profiles.some((p) => p.profile === "ai_engineering_agent"),
    );
  });

  it("exports entitlement map and plan codes", () => {
    assert.equal(ENTITLEMENT_ACTION_MAP.package_publish, "package.publish");
    assert.equal(OS20_PLAN_CODES.enterprise, "os20_enterprise");
  });

  it("AI agent profile denies publish/sign/delegate", () => {
    const ai = CATALOG_SEED.profiles.find(
      (p) => p.profile === "ai_engineering_agent",
    );
    assert.ok(ai);
    const denyPublish = ai!.permissions.find(
      (c) => c.action === "package.publish" && c.effect === "deny",
    );
    assert.ok(denyPublish);
  });
});
