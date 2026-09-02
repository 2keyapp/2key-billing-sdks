import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  CATALOG_SEED,
  ENTITLEMENT_ACTION_MAP,
  EXAMPLE_INVOICE_FSM,
  PRODUCT_DISPLAY_NAME,
  SCOMM_PLAN_CODES,
  SERVICE_ID,
} from "./index.js";

describe("@2key/catalog-scomm (Scomm Workflows)", () => {
  it("seeds serviceId scomm with Workflows branding", () => {
    assert.equal(SERVICE_ID, "scomm");
    assert.equal(PRODUCT_DISPLAY_NAME, "Scomm Workflows");
    assert.equal(CATALOG_SEED.serviceId, "scomm");
    assert.ok(CATALOG_SEED.actions.length > 15);
  });

  it("uses path_prefix channel and optional doc_kind", () => {
    const channel = CATALOG_SEED.scopeDimensions.find(
      (d) => d.dimension === "channel",
    );
    assert.equal(channel?.algebra, "path_prefix");
    const docKind = CATALOG_SEED.scopeDimensions.find(
      (d) => d.dimension === "doc_kind",
    );
    assert.equal(docKind?.algebra, "set");
  });

  it("includes workflow profiles", () => {
    for (const name of [
      "channel_admin",
      "author",
      "reviewer",
      "publisher",
      "viewer",
      "workflow_bot",
    ]) {
      assert.ok(CATALOG_SEED.profiles.some((p) => p.profile === name), name);
    }
  });

  it("author denies approve/publish; reviewer can approve", () => {
    const author = CATALOG_SEED.profiles.find((p) => p.profile === "author");
    const reviewer = CATALOG_SEED.profiles.find((p) => p.profile === "reviewer");
    assert.ok(author);
    assert.ok(reviewer);
    assert.ok(
      author!.permissions.some(
        (c) => c.action === "doc.approve" && c.effect === "deny",
      ),
    );
    assert.ok(
      reviewer!.permissions.some(
        (c) => c.action === "doc.approve" && c.effect !== "deny",
      ),
    );
  });

  it("example FSM only references catalog actions", () => {
    const catalogActions = new Set(CATALOG_SEED.actions.map((a) => a.action));
    for (const state of Object.values(EXAMPLE_INVOICE_FSM.states)) {
      for (const action of state.allowedActions) {
        assert.ok(catalogActions.has(action), `missing ${action}`);
      }
      for (const action of Object.keys(state.transitions)) {
        assert.ok(catalogActions.has(action), `missing transition ${action}`);
      }
    }
  });

  it("exports entitlement map and plan codes", () => {
    assert.equal(ENTITLEMENT_ACTION_MAP.doc_approve, "doc.approve");
    assert.equal(SCOMM_PLAN_CODES.team, "scomm_workflows_team");
  });
});
