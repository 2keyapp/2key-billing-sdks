import type { CapabilitySet, CatalogSeed } from "@2key/dp-spec";

/**
 * Stable serviceId / tenant slug for Scomm Workflows.
 * Wire: `delegatePermissions({ serviceId: SERVICE_ID, seed: CATALOG_SEED })`
 *
 * Product display name: **Scomm Workflows** (formerly sketched as "xdoc").
 * Channels hold documents whose lifecycle is a per-channel FSM. Catalog actions
 * name FSM transitions; FSM state enforcement is PEP + channel config — not a
 * scope algebra.
 */
export const SERVICE_ID = "scomm";

/** User-facing product name (not the serviceId slug). */
export const PRODUCT_DISPLAY_NAME = "Scomm Workflows";

/**
 * Scomm Workflows — channel-scoped document workflows.
 *
 * - Organization (`entity`) owns many channels.
 * - Users hold channel-scoped CapabilitySets (actions).
 * - Documents are instances on a channel; visibility = grants ∩ FSM-allowed
 *   actions for the document's current state.
 * - Document `state` is NOT a grant dimension.
 *
 * Channel hierarchy uses `path_prefix` (e.g. `legal` covers `legal/contracts`).
 * Requires DP algebra v2 (`path_prefix`; optional `effect: "deny"`).
 *
 * See README.md and BILLING_PACKAGES.md.
 */

export const SCOMM_DOC_KINDS = [
  "generic",
  "invoice",
  "contract",
  "memo",
  "form",
  "policy",
] as const;

const SCOMM_ACTIONS = [
  // --- Control plane ---
  { action: "entity.read", description: "Read org Workflows metadata" },
  { action: "channel.create", description: "Create a channel under entity" },
  {
    action: "channel.read",
    description: "List/read channel metadata and FSM config",
  },
  {
    action: "channel.configure",
    description: "Edit channel settings / FSM definition",
  },
  { action: "channel.delete", description: "Remove channel" },
  {
    action: "grant.delegate",
    description: "Issue narrower channel grants to others",
  },
  {
    action: "delegation.revoke",
    description: "Revoke delegated channel grants",
  },
  { action: "admin.invite", description: "Invite org/channel admin" },
  { action: "cert.issue", description: "Sign downstream machine credentials" },
  { action: "machine.bind", description: "Bind automation / bot principal" },
  { action: "seat.bind", description: "Bind permanent machine seat in Billing" },

  // --- Document plane (CRUD) ---
  { action: "doc.create", description: "Create document on channel" },
  { action: "doc.read", description: "Read document content/metadata" },
  { action: "doc.list", description: "List documents on channel" },
  { action: "doc.update", description: "Edit document while state allows" },
  { action: "doc.delete", description: "Delete or withdraw document" },
  { action: "doc.comment", description: "Comment without FSM transition" },

  // --- FSM transition actions (names MUST match channel FSM triggers) ---
  { action: "doc.submit", description: "Submit for review / next state" },
  { action: "doc.approve", description: "Approve document" },
  { action: "doc.reject", description: "Reject document" },
  {
    action: "doc.request_changes",
    description: "Request changes (return to editable state)",
  },
  { action: "doc.publish", description: "Publish approved document" },
  { action: "doc.archive", description: "Archive document" },
  { action: "doc.restore", description: "Restore from archive" },
] as const;

const SCOMM_SCOPE_DIMENSIONS = [
  { dimension: "entity", algebra: "exact" as const },
  /**
   * Channel within org. Hierarchical paths use `/`
   * (e.g. legal covers legal/contracts under path_prefix).
   */
  { dimension: "channel", algebra: "path_prefix" as const },
  /**
   * Optional template/type filter when one channel hosts multiple kinds
   * with different action needs.
   */
  { dimension: "doc_kind", algebra: "set" as const },
] as const;

// --- Profiles (convenience bundles → CapabilitySet) ---

/** Org / channel admin — configure FSM, delegate, full doc ops. */
const channelAdminPermissions: CapabilitySet = [
  { action: "entity.read", scope: {}, delegable: true },
  { action: "channel.create", scope: { channel: "" }, delegable: true },
  { action: "channel.read", scope: { channel: "" }, delegable: true },
  { action: "channel.configure", scope: { channel: "" }, delegable: true },
  { action: "channel.delete", scope: { channel: "" }, delegable: true },
  { action: "grant.delegate", scope: { channel: "" }, delegable: true },
  { action: "delegation.revoke", scope: { channel: "" }, delegable: true },
  { action: "admin.invite", scope: {}, delegable: true },
  { action: "cert.issue", scope: { channel: "" }, delegable: true },
  { action: "machine.bind", scope: { channel: "" }, delegable: true },
  { action: "seat.bind", scope: {}, delegable: true },
  { action: "doc.create", scope: { channel: "" }, delegable: true },
  { action: "doc.read", scope: { channel: "" }, delegable: true },
  { action: "doc.list", scope: { channel: "" }, delegable: true },
  { action: "doc.update", scope: { channel: "" }, delegable: true },
  { action: "doc.delete", scope: { channel: "" }, delegable: true },
  { action: "doc.comment", scope: { channel: "" }, delegable: true },
  { action: "doc.submit", scope: { channel: "" }, delegable: true },
  { action: "doc.approve", scope: { channel: "" }, delegable: true },
  { action: "doc.reject", scope: { channel: "" }, delegable: true },
  { action: "doc.request_changes", scope: { channel: "" }, delegable: true },
  { action: "doc.publish", scope: { channel: "" }, delegable: true },
  { action: "doc.archive", scope: { channel: "" }, delegable: true },
  { action: "doc.restore", scope: { channel: "" }, delegable: true },
];

/** Author — create/edit/submit; no approve/publish by default. */
const authorPermissions: CapabilitySet = [
  { action: "channel.read", scope: { channel: "" }, delegable: false },
  { action: "doc.create", scope: { channel: "" }, delegable: false },
  { action: "doc.read", scope: { channel: "" }, delegable: false },
  { action: "doc.list", scope: { channel: "" }, delegable: false },
  { action: "doc.update", scope: { channel: "" }, delegable: false },
  { action: "doc.delete", scope: { channel: "" }, delegable: false },
  { action: "doc.comment", scope: { channel: "" }, delegable: false },
  { action: "doc.submit", scope: { channel: "" }, delegable: false },
  {
    action: "doc.approve",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "doc.publish",
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
  {
    action: "channel.configure",
    scope: {},
    delegable: false,
    effect: "deny",
  },
];

/** Reviewer — read + approve/reject/request_changes. */
const reviewerPermissions: CapabilitySet = [
  { action: "channel.read", scope: { channel: "" }, delegable: false },
  { action: "doc.read", scope: { channel: "" }, delegable: false },
  { action: "doc.list", scope: { channel: "" }, delegable: false },
  { action: "doc.comment", scope: { channel: "" }, delegable: false },
  { action: "doc.approve", scope: { channel: "" }, delegable: false },
  { action: "doc.reject", scope: { channel: "" }, delegable: false },
  { action: "doc.request_changes", scope: { channel: "" }, delegable: false },
  {
    action: "doc.create",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "doc.publish",
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

/** Publisher — publish/archive after approval path. */
const publisherPermissions: CapabilitySet = [
  { action: "channel.read", scope: { channel: "" }, delegable: false },
  { action: "doc.read", scope: { channel: "" }, delegable: false },
  { action: "doc.list", scope: { channel: "" }, delegable: false },
  { action: "doc.publish", scope: { channel: "" }, delegable: false },
  { action: "doc.archive", scope: { channel: "" }, delegable: false },
  { action: "doc.restore", scope: { channel: "" }, delegable: false },
  {
    action: "doc.approve",
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

/** Viewer — read-only inbox. */
const viewerPermissions: CapabilitySet = [
  { action: "channel.read", scope: { channel: "" }, delegable: false },
  { action: "doc.read", scope: { channel: "" }, delegable: false },
  { action: "doc.list", scope: { channel: "" }, delegable: false },
  { action: "doc.comment", scope: { channel: "" }, delegable: false },
  {
    action: "doc.update",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "doc.approve",
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

/** Automation bot — create/submit/comment; deny approve/configure/delegate. */
const workflowBotPermissions: CapabilitySet = [
  { action: "doc.create", scope: { channel: "" }, delegable: false },
  { action: "doc.read", scope: { channel: "" }, delegable: false },
  { action: "doc.update", scope: { channel: "" }, delegable: false },
  { action: "doc.submit", scope: { channel: "" }, delegable: false },
  { action: "doc.comment", scope: { channel: "" }, delegable: false },
  {
    action: "doc.approve",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "doc.publish",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "channel.configure",
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
  actions: SCOMM_ACTIONS,
  scopeDimensions: SCOMM_SCOPE_DIMENSIONS,
  profiles: [
    { profile: "channel_admin", permissions: channelAdminPermissions },
    { profile: "author", permissions: authorPermissions },
    { profile: "reviewer", permissions: reviewerPermissions },
    { profile: "publisher", permissions: publisherPermissions },
    { profile: "viewer", permissions: viewerPermissions },
    { profile: "workflow_bot", permissions: workflowBotPermissions },
  ],
};

/**
 * Map Scomm Workflows API / entitlement JWT action names → catalog actions.
 */
export const ENTITLEMENT_ACTION_MAP = {
  channel_create: "channel.create",
  channel_configure: "channel.configure",
  doc_create: "doc.create",
  doc_read: "doc.read",
  doc_submit: "doc.submit",
  doc_approve: "doc.approve",
  doc_publish: "doc.publish",
  grant_delegate: "grant.delegate",
} as const;

/** Commercial package codes for Billing seed. */
export const SCOMM_PLAN_CODES = {
  starter: "scomm_workflows_starter",
  team: "scomm_workflows_team",
  enterprise: "scomm_workflows_enterprise",
  machineSeat: "scomm_workflows_machine_seat",
} as const;

/** Usage meters (org pays). */
export const SCOMM_METERS = {
  apiCalls: "scomm.workflows.api.calls",
  documentsActive: "scomm.workflows.documents.active",
  storageBytes: "scomm.workflows.storage.bytes",
  transitions: "scomm.workflows.transitions",
} as const;

/**
 * Example channel FSM (illustrative). Stored per channel in app DB;
 * every action string must exist in this catalog.
 */
export const EXAMPLE_INVOICE_FSM = {
  channelId: "finance/invoices",
  initial: "draft",
  states: {
    draft: {
      allowedActions: ["doc.update", "doc.submit", "doc.delete", "doc.read"],
      transitions: { "doc.submit": "pending_review" },
    },
    pending_review: {
      allowedActions: [
        "doc.read",
        "doc.approve",
        "doc.reject",
        "doc.request_changes",
        "doc.comment",
      ],
      transitions: {
        "doc.approve": "approved",
        "doc.reject": "draft",
        "doc.request_changes": "draft",
      },
    },
    approved: {
      allowedActions: ["doc.read", "doc.publish", "doc.archive"],
      transitions: {
        "doc.publish": "published",
        "doc.archive": "archived",
      },
    },
    published: {
      allowedActions: ["doc.read", "doc.archive"],
      transitions: { "doc.archive": "archived" },
    },
    archived: {
      allowedActions: ["doc.read", "doc.restore"],
      transitions: { "doc.restore": "draft" },
    },
  },
} as const;
