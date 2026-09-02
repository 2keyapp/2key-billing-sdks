import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  CATALOG_SEED,
  ENTITLEMENT_ACTION_MAP,
  MNMS_PLAN_CODES,
  SERVICE_ID,
} from "./index.js";

describe("@2key/catalog-mnms", () => {
  it("seeds serviceId mnms with actions, dimensions, and profiles", () => {
    assert.equal(SERVICE_ID, "mnms");
    assert.equal(CATALOG_SEED.serviceId, "mnms");
    assert.ok(CATALOG_SEED.actions.length > 40);
    const app = CATALOG_SEED.scopeDimensions.find((d) => d.dimension === "app");
    assert.equal(app?.algebra, "path_prefix");
    const container = CATALOG_SEED.scopeDimensions.find(
      (d) => d.dimension === "container",
    );
    assert.equal(container?.algebra, "path_prefix");
    const tablespace = CATALOG_SEED.scopeDimensions.find(
      (d) => d.dimension === "tablespace",
    );
    assert.equal(tablespace?.algebra, "path_prefix");
    assert.ok(CATALOG_SEED.profiles.some((p) => p.profile === "app_owner"));
    assert.ok(CATALOG_SEED.profiles.some((p) => p.profile === "admin"));
    assert.ok(CATALOG_SEED.profiles.some((p) => p.profile === "sysops"));
    assert.ok(CATALOG_SEED.profiles.some((p) => p.profile === "dbaops"));
    assert.ok(CATALOG_SEED.profiles.some((p) => p.profile === "appdev"));
  });

  it("exports entitlement map and plan codes", () => {
    assert.equal(ENTITLEMENT_ACTION_MAP.container_start, "sysops.container.start");
    assert.equal(MNMS_PLAN_CODES.enterprise, "mnms_enterprise");
  });

  it("appdev profile denies production deploy and container exec", () => {
    const appdev = CATALOG_SEED.profiles.find((p) => p.profile === "appdev");
    assert.ok(appdev);
    assert.ok(
      appdev!.permissions.some(
        (c) => c.action === "appdev.deploy.production" && c.effect === "deny",
      ),
    );
    assert.ok(
      appdev!.permissions.some(
        (c) => c.action === "sysops.container.exec" && c.effect === "deny",
      ),
    );
  });

  it("admin profile can subdelegate but leaf sysops cannot", () => {
    const admin = CATALOG_SEED.profiles.find((p) => p.profile === "admin");
    const sysops = CATALOG_SEED.profiles.find((p) => p.profile === "sysops");
    assert.ok(admin);
    assert.ok(sysops);
    assert.ok(
      admin!.permissions.some(
        (c) => c.action === "delegation.grant" && c.delegable === true,
      ),
    );
    assert.ok(
      sysops!.permissions.some(
        (c) => c.action === "delegation.grant" && c.effect === "deny",
      ),
    );
  });
});
