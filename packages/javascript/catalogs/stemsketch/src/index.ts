import type { CapabilitySet, CatalogSeed } from "@2key/dp-spec";

/**
 * Stable serviceId / tenant slug for STEMSketch.
 * Wire: `delegatePermissions({ serviceId: SERVICE_ID, seed: CATALOG_SEED })`
 *
 * Product: VS Code extension + knowledgebase. Knowledge is classified under an
 * ontology tree. Root delegates ontology scopes (e.g. physics vs biology) to
 * admins who may further attenuate. Submit-for-review and make-live (publish)
 * are distinct actions — never implied by each other.
 *
 * Requires DP algebra v2 (`path_prefix`; optional `effect: "deny"`).
 * See README.md and BILLING_PACKAGES.md.
 */
export const SERVICE_ID = "stemsketch";

/** User-facing product name. */
export const PRODUCT_DISPLAY_NAME = "STEMSketch";

/** Example top-level ontology roots (illustrative; orgs extend freely). */
export const STEMSKETCH_ONTOLOGY_ROOTS = [
  "physics",
  "biology",
  "chemistry",
  "mathematics",
  "engineering",
  "computer-science",
] as const;

export const STEMSKETCH_ENVIRONMENTS = [
  "draft-space",
  "staging",
  "production",
] as const;

/**
 * Artifact lifecycle states (app-owned). Not a grant scope dimension —
 * enforced at PEP after authorize().
 */
export const STEMSKETCH_ARTIFACT_STATES = [
  "draft",
  "in_review",
  "approved",
  "live",
  "deprecated",
] as const;

const STEMSKETCH_ACTIONS = [
  // --- Control / ontology admin ---
  { action: "entity.read", description: "Read org STEMSketch metadata" },
  { action: "ontology.read", description: "Read ontology taxonomy under scope" },
  {
    action: "ontology.manage",
    description: "Create/rename/reparent ontology nodes under scope",
  },
  {
    action: "grant.delegate",
    description: "Issue attenuated ontology-scoped grants",
  },
  {
    action: "delegation.revoke",
    description: "Revoke delegated grants under scope",
  },
  { action: "admin.invite", description: "Invite org / ontology admin" },
  { action: "cert.issue", description: "Sign downstream machine credentials" },
  { action: "machine.bind", description: "Bind automation / import bot" },
  { action: "seat.bind", description: "Bind permanent machine seat in Billing" },

  // --- Knowledge artifacts (VS Code + API) ---
  {
    action: "kb.discover",
    description: "Discover artifact existence without full content",
  },
  { action: "kb.read", description: "Read knowledge artifact content" },
  { action: "kb.create", description: "Create knowledge artifact" },
  { action: "kb.update", description: "Update draft / editable artifact" },
  { action: "kb.delete", description: "Delete artifact (state-gated at PEP)" },
  {
    action: "kb.submit_review",
    description: "Submit artifact for review (not make-live)",
  },
  {
    action: "kb.withdraw_review",
    description: "Withdraw artifact from review back to draft",
  },
  { action: "kb.approve", description: "Approve artifact in review" },
  { action: "kb.reject", description: "Reject artifact in review" },
  {
    action: "kb.request_changes",
    description: "Request changes (return to draft)",
  },
  {
    action: "kb.publish",
    description: "Make artifact live in the knowledgebase",
  },
  {
    action: "kb.unpublish",
    description: "Remove artifact from live knowledgebase",
  },
  { action: "kb.deprecate", description: "Mark live artifact deprecated" },
] as const;

const STEMSKETCH_SCOPE_DIMENSIONS = [
  { dimension: "entity", algebra: "exact" as const },
  /**
   * Ontology tree. Root phrase "physics.*" maps to ontology: "physics"
   * (path_prefix covers physics/mechanics, …).
   */
  { dimension: "ontology", algebra: "path_prefix" as const },
  /** Optional finer path to a specific artifact under an ontology. */
  { dimension: "artifact", algebra: "path_prefix" as const },
  { dimension: "environment", algebra: "set" as const },
] as const;

// --- Profiles ---

/** Org root — all ontologies; can delegate domain admins. */
const kbRootPermissions: CapabilitySet = [
  { action: "entity.read", scope: {}, delegable: true },
  { action: "ontology.read", scope: { ontology: "" }, delegable: true },
  { action: "ontology.manage", scope: { ontology: "" }, delegable: true },
  { action: "grant.delegate", scope: { ontology: "" }, delegable: true },
  { action: "delegation.revoke", scope: { ontology: "" }, delegable: true },
  { action: "admin.invite", scope: {}, delegable: true },
  { action: "cert.issue", scope: { ontology: "" }, delegable: true },
  { action: "machine.bind", scope: { ontology: "" }, delegable: true },
  { action: "seat.bind", scope: {}, delegable: true },
  { action: "kb.discover", scope: { ontology: "" }, delegable: true },
  { action: "kb.read", scope: { ontology: "" }, delegable: true },
  { action: "kb.create", scope: { ontology: "" }, delegable: true },
  { action: "kb.update", scope: { ontology: "" }, delegable: true },
  { action: "kb.delete", scope: { ontology: "" }, delegable: true },
  { action: "kb.submit_review", scope: { ontology: "" }, delegable: true },
  { action: "kb.withdraw_review", scope: { ontology: "" }, delegable: true },
  { action: "kb.approve", scope: { ontology: "" }, delegable: true },
  { action: "kb.reject", scope: { ontology: "" }, delegable: true },
  { action: "kb.request_changes", scope: { ontology: "" }, delegable: true },
  { action: "kb.publish", scope: { ontology: "" }, delegable: true },
  { action: "kb.unpublish", scope: { ontology: "" }, delegable: true },
  { action: "kb.deprecate", scope: { ontology: "" }, delegable: true },
];

/**
 * Domain / ontology admin — narrow `ontology` at issue (e.g. physics).
 * May subdelegate within that tree.
 */
const ontologyAdminPermissions: CapabilitySet = [
  { action: "ontology.read", scope: { ontology: "" }, delegable: true },
  { action: "ontology.manage", scope: { ontology: "" }, delegable: true },
  { action: "grant.delegate", scope: { ontology: "" }, delegable: true },
  { action: "delegation.revoke", scope: { ontology: "" }, delegable: false },
  { action: "kb.discover", scope: { ontology: "" }, delegable: true },
  { action: "kb.read", scope: { ontology: "" }, delegable: true },
  { action: "kb.create", scope: { ontology: "" }, delegable: true },
  { action: "kb.update", scope: { ontology: "" }, delegable: true },
  { action: "kb.delete", scope: { ontology: "" }, delegable: true },
  { action: "kb.submit_review", scope: { ontology: "" }, delegable: true },
  { action: "kb.withdraw_review", scope: { ontology: "" }, delegable: true },
  { action: "kb.approve", scope: { ontology: "" }, delegable: true },
  { action: "kb.reject", scope: { ontology: "" }, delegable: true },
  { action: "kb.request_changes", scope: { ontology: "" }, delegable: true },
  { action: "kb.publish", scope: { ontology: "" }, delegable: false },
  { action: "kb.unpublish", scope: { ontology: "" }, delegable: false },
  { action: "kb.deprecate", scope: { ontology: "" }, delegable: false },
];

/** VS Code author — contribute + submit; deny publish / delegate. */
const authorPermissions: CapabilitySet = [
  { action: "ontology.read", scope: { ontology: "" }, delegable: false },
  { action: "kb.discover", scope: { ontology: "" }, delegable: false },
  { action: "kb.read", scope: { ontology: "" }, delegable: false },
  { action: "kb.create", scope: { ontology: "" }, delegable: false },
  { action: "kb.update", scope: { ontology: "" }, delegable: false },
  { action: "kb.delete", scope: { ontology: "" }, delegable: false },
  { action: "kb.submit_review", scope: { ontology: "" }, delegable: false },
  { action: "kb.withdraw_review", scope: { ontology: "" }, delegable: false },
  {
    action: "kb.approve",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "kb.publish",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "kb.unpublish",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "grant.delegate",
    scope: {},
    delegable: false,
    effect: "deny",
  },
];

/** Reviewer — approve/reject; deny publish / delegate. */
const reviewerPermissions: CapabilitySet = [
  { action: "ontology.read", scope: { ontology: "" }, delegable: false },
  { action: "kb.discover", scope: { ontology: "" }, delegable: false },
  { action: "kb.read", scope: { ontology: "" }, delegable: false },
  { action: "kb.approve", scope: { ontology: "" }, delegable: false },
  { action: "kb.reject", scope: { ontology: "" }, delegable: false },
  { action: "kb.request_changes", scope: { ontology: "" }, delegable: false },
  {
    action: "kb.create",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "kb.publish",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "grant.delegate",
    scope: {},
    delegable: false,
    effect: "deny",
  },
];

/** Publisher — make live / unpublish / deprecate. */
const publisherPermissions: CapabilitySet = [
  { action: "ontology.read", scope: { ontology: "" }, delegable: false },
  { action: "kb.discover", scope: { ontology: "" }, delegable: false },
  { action: "kb.read", scope: { ontology: "" }, delegable: false },
  { action: "kb.publish", scope: { ontology: "" }, delegable: false },
  { action: "kb.unpublish", scope: { ontology: "" }, delegable: false },
  { action: "kb.deprecate", scope: { ontology: "" }, delegable: false },
  {
    action: "kb.approve",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "grant.delegate",
    scope: {},
    delegable: false,
    effect: "deny",
  },
];

const viewerPermissions: CapabilitySet = [
  { action: "ontology.read", scope: { ontology: "" }, delegable: false },
  { action: "kb.discover", scope: { ontology: "" }, delegable: false },
  { action: "kb.read", scope: { ontology: "" }, delegable: false },
  {
    action: "kb.update",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "kb.publish",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "grant.delegate",
    scope: {},
    delegable: false,
    effect: "deny",
  },
];

/** Import / sync bot — create/update/submit; deny approve/publish/delegate. */
const kbBotPermissions: CapabilitySet = [
  { action: "kb.discover", scope: { ontology: "" }, delegable: false },
  { action: "kb.read", scope: { ontology: "" }, delegable: false },
  { action: "kb.create", scope: { ontology: "" }, delegable: false },
  { action: "kb.update", scope: { ontology: "" }, delegable: false },
  { action: "kb.submit_review", scope: { ontology: "" }, delegable: false },
  {
    action: "kb.approve",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "kb.publish",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "grant.delegate",
    scope: {},
    delegable: false,
    effect: "deny",
  },
];

export const CATALOG_SEED: CatalogSeed = {
  serviceId: SERVICE_ID,
  actions: STEMSKETCH_ACTIONS,
  scopeDimensions: STEMSKETCH_SCOPE_DIMENSIONS,
  profiles: [
    { profile: "kb_root", permissions: kbRootPermissions },
    { profile: "ontology_admin", permissions: ontologyAdminPermissions },
    { profile: "author", permissions: authorPermissions },
    { profile: "reviewer", permissions: reviewerPermissions },
    { profile: "publisher", permissions: publisherPermissions },
    { profile: "viewer", permissions: viewerPermissions },
    { profile: "kb_bot", permissions: kbBotPermissions },
  ],
};

/**
 * Map STEMSketch API / entitlement JWT action names → catalog actions.
 */
export const ENTITLEMENT_ACTION_MAP = {
  ontology_manage: "ontology.manage",
  kb_create: "kb.create",
  kb_update: "kb.update",
  kb_submit_review: "kb.submit_review",
  kb_approve: "kb.approve",
  kb_publish: "kb.publish",
  grant_delegate: "grant.delegate",
} as const;

/** Commercial package codes for Billing seed. */
export const STEMSKETCH_PLAN_CODES = {
  starter: "stemsketch_starter",
  team: "stemsketch_team",
  enterprise: "stemsketch_enterprise",
  authorSeat: "stemsketch_author_seat",
  machineSeat: "stemsketch_machine_seat",
} as const;

/** Usage meters (org pays). */
export const STEMSKETCH_METERS = {
  apiCalls: "stemsketch.api.calls",
  artifactsActive: "stemsketch.artifacts.active",
  storageBytes: "stemsketch.storage.bytes",
  publishEvents: "stemsketch.publish.events",
} as const;

/**
 * Example artifact lifecycle (illustrative). Enforced at PEP after authorize().
 * Keys = states; values = catalog actions typically allowed.
 */
export const EXAMPLE_ARTIFACT_LIFECYCLE = {
  draft: ["kb.read", "kb.update", "kb.delete", "kb.submit_review"],
  in_review: [
    "kb.read",
    "kb.approve",
    "kb.reject",
    "kb.request_changes",
    "kb.withdraw_review",
  ],
  approved: ["kb.read", "kb.publish", "kb.request_changes"],
  live: ["kb.read", "kb.unpublish", "kb.deprecate"],
  deprecated: ["kb.read", "kb.unpublish"],
} as const;
