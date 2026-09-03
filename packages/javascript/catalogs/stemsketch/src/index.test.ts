import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  CATALOG_SEED,
  ENTITLEMENT_ACTION_MAP,
  EXAMPLE_ARTIFACT_LIFECYCLE,
  PRODUCT_DISPLAY_NAME,
  SERVICE_ID,
  STEMSKETCH_PLAN_CODES,
} from "./index.js";

describe("@2key/catalog-stemsketch (STEMSketch)", () => {
  it("seeds serviceId stemsketch", () => {
    assert.equal(SERVICE_ID, "stemsketch");
    assert.equal(PRODUCT_DISPLAY_NAME, "STEMSketch");
    assert.equal(CATALOG_SEED.serviceId, "stemsketch");
    assert.ok(CATALOG_SEED.actions.length > 15);
  });

  it("uses path_prefix ontology dimension", () => {
    const ontology = CATALOG_SEED.scopeDimensions.find(
      (d) => d.dimension === "ontology",
    );
    assert.equal(ontology?.algebra, "path_prefix");
  });

  it("includes expected profiles", () => {
    for (const name of [
      "kb_root",
      "ontology_admin",
      "author",
      "reviewer",
      "publisher",
      "viewer",
      "kb_bot",
    ]) {
      assert.ok(CATALOG_SEED.profiles.some((p) => p.profile === name), name);
    }
  });

  it("author can submit_review but denies publish", () => {
    const author = CATALOG_SEED.profiles.find((p) => p.profile === "author");
    assert.ok(author);
    assert.ok(
      author!.permissions.some(
        (c) => c.action === "kb.submit_review" && c.effect !== "deny",
      ),
    );
    assert.ok(
      author!.permissions.some(
        (c) => c.action === "kb.publish" && c.effect === "deny",
      ),
    );
  });

  it("ontology_admin can grant.delegate; author cannot", () => {
    const admin = CATALOG_SEED.profiles.find(
      (p) => p.profile === "ontology_admin",
    );
    const author = CATALOG_SEED.profiles.find((p) => p.profile === "author");
    assert.ok(admin);
    assert.ok(author);
    assert.ok(
      admin!.permissions.some(
        (c) => c.action === "grant.delegate" && c.delegable === true,
      ),
    );
    assert.ok(
      author!.permissions.some(
        (c) => c.action === "grant.delegate" && c.effect === "deny",
      ),
    );
  });

  it("example lifecycle only references catalog actions", () => {
    const catalogActions = new Set(CATALOG_SEED.actions.map((a) => a.action));
    for (const actions of Object.values(EXAMPLE_ARTIFACT_LIFECYCLE)) {
      for (const action of actions) {
        assert.ok(catalogActions.has(action), `missing ${action}`);
      }
    }
  });

  it("exports entitlement map and plan codes", () => {
    assert.equal(ENTITLEMENT_ACTION_MAP.kb_publish, "kb.publish");
    assert.equal(STEMSKETCH_PLAN_CODES.team, "stemsketch_team");
  });
});
