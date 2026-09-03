import type { CapabilitySet, CatalogSeed } from "@2key/dp-spec";

/**
 * Stable serviceId / tenant slug for OS20.
 * Wire: `delegatePermissions({ serviceId: SERVICE_ID, seed: CATALOG_SEED })`
 */
export const SERVICE_ID = "os20";

/**
 * OS20 — Engineering package manager + Workbench (SysML 2 / KerML-style semantics).
 *
 * Naming / scope conventions:
 * - Entity apex binds the merchant org (Billing entityId).
 * - `org` uses path_prefix for namespace trees: `@acme`, `@acme/engineering`, …
 * - `resource` uses path_prefix for packages/elements:
 *   `@acme/turbofan`, `@acme/turbofan/Rotor`, `@acme/turbofan/Rotor/mass`
 *   (PEP/resolver should canonicalize `::` element syntax to `/` before AuthZ.)
 * - `version` uses semver algebra (exact vs range attenuation).
 * - Semantic / relation / lifecycle / visibility / environment use set algebra.
 *
 * AuthN / AuthZ / PEP overview: see README.md.
 * Commercial packages: see BILLING_PACKAGES.md.
 */

/** Built-in semantic domain URNs — ontology service is authoritative at runtime. */
export const OS20_SEMANTIC_DOMAINS = [
  "urn:os20:semantic:design",
  "urn:os20:semantic:behaviour",
  "urn:os20:semantic:requirements",
  "urn:os20:semantic:geometry",
  "urn:os20:semantic:simulation",
  "urn:os20:semantic:simulation:cfd",
  "urn:os20:semantic:simulation:fea",
  "urn:os20:semantic:simulation:thermal",
  "urn:os20:semantic:validation",
  "urn:os20:semantic:verification",
  "urn:os20:semantic:manufacturing",
  "urn:os20:semantic:software",
  "urn:os20:semantic:controls",
  "urn:os20:semantic:electrical",
  "urn:os20:semantic:thermal",
  "urn:os20:semantic:structural",
  "urn:os20:semantic:safety",
  "urn:os20:semantic:compliance",
  "urn:os20:semantic:commercial",
  "urn:os20:semantic:documentation",
] as const;

export const OS20_RELATION_TYPES = [
  "kerml:specializes",
  "kerml:extends",
  "os20:specifies",
  "os20:implements",
  "os20:satisfies",
  "os20:validates",
  "os20:verifies",
  "os20:derivedFrom",
  "os20:manufacturedAs",
  "os20:simulates",
  "os20:replaces",
  "os20:supersedes",
  "os20:composes",
  "os20:references",
  "os20:dependsOn",
] as const;

export const OS20_LIFECYCLE_STATES = [
  "draft",
  "working",
  "review",
  "approved",
  "released",
  "published",
  "deprecated",
  "archived",
] as const;

export const OS20_VISIBILITY_LEVELS = [
  "private",
  "internal",
  "partner",
  "restricted-external",
  "public",
] as const;

export const OS20_ENVIRONMENTS = [
  "local",
  "development",
  "test",
  "staging",
  "certification",
  "production",
  "public-registry",
] as const;

const OS20_ACTIONS = [
  // --- Discovery / read ---
  { action: "read", description: "Read resource content/metadata" },
  { action: "discover", description: "Discover existence without full content" },
  { action: "relation.read", description: "Read graph edges (distinct from node read)" },
  { action: "property.read", description: "Read element properties" },

  // --- Mutation ---
  { action: "create", description: "Create resource" },
  {
    action: "modify",
    description:
      "Modify resource (does not imply approve, sign, publish, or delegate)",
  },
  { action: "modify.create", description: "Create sub-resource" },
  { action: "modify.update", description: "Update existing resource" },
  { action: "modify.delete", description: "Delete resource" },
  {
    action: "propose",
    description: "Propose a change (AI agent); not adopt/approve",
  },
  { action: "execute", description: "Execute simulation/tooling" },
  { action: "import", description: "Import external content" },
  { action: "export", description: "Export content" },
  { action: "derive", description: "Create derived artifact" },
  { action: "override", description: "Override inherited value" },

  // --- Governance ---
  { action: "review", description: "Review without final approval" },
  { action: "approve", description: "Approve change/release" },
  { action: "reject", description: "Reject change/release" },
  { action: "attest", description: "Attest to claim/evidence" },
  {
    action: "sign",
    description: "Cryptographic signature on release/attestation",
  },

  // --- Publication / disclosure ---
  { action: "publish", description: "Publish to broader visibility/environment" },
  { action: "unpublish", description: "Withdraw from public/partner visibility" },
  { action: "deprecate", description: "Mark deprecated" },
  { action: "archive", description: "Archive immutable record" },
  { action: "disclosure.promote", description: "Increase visibility level" },
  { action: "disclosure.demote", description: "Decrease visibility level" },

  // --- Lifecycle transitions ---
  { action: "lifecycle.submit_review", description: "Transition → review" },
  { action: "lifecycle.approve", description: "Transition → approved" },
  { action: "lifecycle.release", description: "Transition → released" },
  { action: "lifecycle.publish", description: "Transition → published" },
  { action: "lifecycle.deprecate", description: "Transition → deprecated" },
  { action: "lifecycle.archive", description: "Transition → archived" },

  // --- Relation operations (compose with relation scope) ---
  { action: "relation.link", description: "Create typed relation edge" },
  { action: "relation.unlink", description: "Remove typed relation edge" },
  { action: "relation.approve", description: "Approve cross-domain relation" },

  // --- Namespace / organization ---
  { action: "namespace.read", description: "Read namespace metadata" },
  { action: "namespace.create", description: "Create sub-namespace" },
  { action: "namespace.manage", description: "Manage namespace settings" },
  { action: "namespace.delegate", description: "Delegate namespace authority" },
  { action: "namespace.transfer", description: "Transfer namespace ownership" },
  { action: "organization.manage", description: "Manage organization" },
  {
    action: "organization.policy.manage",
    description: "Manage organization AuthZ policies",
  },
  { action: "organization.ca.manage", description: "Manage organization CA" },

  // --- Package lifecycle ---
  { action: "package.read", description: "Read package metadata" },
  { action: "package.release", description: "Create immutable release" },
  {
    action: "package.publish",
    description: "Publish package to registry/environment",
  },
  { action: "package.sign", description: "Sign release manifest" },

  // --- Delegation / admin / PKI ---
  { action: "delegation.grant", description: "Issue delegated capability" },
  { action: "delegation.revoke", description: "Revoke delegated capability" },
  { action: "administer", description: "Administrative operations" },
  { action: "admin.invite", description: "Invite interim admin identity" },
  { action: "cert.issue", description: "Sign downstream capability credentials" },
  { action: "entity.read", description: "Read entity control-plane metadata" },
  {
    action: "machine.bind",
    description: "Occupy a machine principal (CI / bot / agent)",
  },
  {
    action: "seat.bind",
    description: "Bind permanent machine seat in Billing",
  },
] as const;

/**
 * Ten OS20 dimensions as catalog scope keys (action is Capability.action).
 * Assurance (dimension 10) is a request predicate — not a scope dimension.
 */
const OS20_SCOPE_DIMENSIONS = [
  { dimension: "entity", algebra: "exact" as const },
  { dimension: "org", algebra: "path_prefix" as const },
  { dimension: "resource", algebra: "path_prefix" as const },
  { dimension: "semantic", algebra: "set" as const },
  { dimension: "relation", algebra: "set" as const },
  { dimension: "lifecycle", algebra: "set" as const },
  { dimension: "visibility", algebra: "set" as const },
  { dimension: "version", algebra: "semver" as const },
  { dimension: "environment", algebra: "set" as const },
] as const;

// --- Profiles (convenience bundles → CapabilitySet; not authority primitives) ---

/** Organization owner / root admin — full org authority, delegable. */
const organizationOwnerPermissions: CapabilitySet = [
  { action: "organization.manage", scope: { org: "" }, delegable: true },
  { action: "organization.policy.manage", scope: { org: "" }, delegable: true },
  { action: "organization.ca.manage", scope: { org: "" }, delegable: true },
  { action: "namespace.read", scope: { org: "" }, delegable: true },
  { action: "namespace.create", scope: { org: "" }, delegable: true },
  { action: "namespace.manage", scope: { org: "" }, delegable: true },
  { action: "namespace.delegate", scope: { org: "" }, delegable: true },
  { action: "namespace.transfer", scope: { org: "" }, delegable: true },
  { action: "delegation.grant", scope: { org: "" }, delegable: true },
  { action: "delegation.revoke", scope: { org: "" }, delegable: true },
  { action: "admin.invite", scope: {}, delegable: true },
  { action: "cert.issue", scope: { org: "" }, delegable: true },
  { action: "entity.read", scope: {}, delegable: true },
  { action: "machine.bind", scope: { org: "" }, delegable: true },
  { action: "seat.bind", scope: {}, delegable: true },
  { action: "read", scope: { org: "" }, delegable: true },
  { action: "modify", scope: { org: "" }, delegable: true },
  { action: "approve", scope: { org: "" }, delegable: true },
  { action: "publish", scope: { org: "" }, delegable: true },
  { action: "package.publish", scope: { org: "" }, delegable: true },
  { action: "package.sign", scope: { org: "" }, delegable: true },
  // Org-wide "deny public publish by default" is composed at the PEP from
  // organization policy (mandatory deny grants), not on this profile — otherwise
  // DENY_OVERRIDE would block legitimate subdelegation of publish.
];

/** Package maintainer — mutate + release within narrowed org/resource at issue. */
const packageMaintainerPermissions: CapabilitySet = [
  { action: "read", scope: { org: "", resource: "" }, delegable: false },
  {
    action: "modify",
    scope: {
      org: "",
      resource: "",
      lifecycle: ["draft", "working"],
    },
    delegable: false,
  },
  { action: "review", scope: { org: "", resource: "" }, delegable: false },
  {
    action: "package.release",
    scope: { org: "", resource: "" },
    delegable: false,
  },
  {
    action: "relation.link",
    scope: { org: "", resource: "", relation: [...OS20_RELATION_TYPES] },
    delegable: false,
  },
  {
    action: "relation.unlink",
    scope: { org: "", resource: "", relation: [...OS20_RELATION_TYPES] },
    delegable: false,
  },
];

const geometryEngineerPermissions: CapabilitySet = [
  { action: "read", scope: { org: "" }, delegable: false },
  {
    action: "modify",
    scope: {
      org: "",
      resource: "",
      semantic: ["urn:os20:semantic:geometry"],
      lifecycle: ["draft", "working"],
    },
    delegable: false,
  },
  {
    action: "review",
    scope: {
      org: "",
      resource: "",
      semantic: ["urn:os20:semantic:geometry"],
    },
    delegable: false,
  },
];

const simulationEngineerPermissions: CapabilitySet = [
  { action: "read", scope: { org: "" }, delegable: false },
  {
    action: "modify",
    scope: {
      org: "",
      resource: "",
      semantic: [
        "urn:os20:semantic:simulation",
        "urn:os20:semantic:simulation:cfd",
        "urn:os20:semantic:simulation:fea",
        "urn:os20:semantic:simulation:thermal",
      ],
      lifecycle: ["draft", "working"],
    },
    delegable: true,
  },
  {
    action: "execute",
    scope: {
      org: "",
      resource: "",
      semantic: ["urn:os20:semantic:simulation"],
    },
    delegable: true,
  },
  {
    action: "approve",
    scope: {
      org: "",
      resource: "",
      semantic: ["urn:os20:semantic:simulation"],
    },
    delegable: false,
  },
];

const validationEngineerPermissions: CapabilitySet = [
  { action: "read", scope: { org: "" }, delegable: false },
  {
    action: "review",
    scope: {
      org: "",
      resource: "",
      semantic: [
        "urn:os20:semantic:validation",
        "urn:os20:semantic:verification",
      ],
    },
    delegable: false,
  },
  {
    action: "approve",
    scope: {
      org: "",
      resource: "",
      semantic: ["urn:os20:semantic:validation"],
    },
    delegable: false,
  },
  {
    action: "attest",
    scope: {
      org: "",
      resource: "",
      semantic: ["urn:os20:semantic:validation"],
    },
    delegable: false,
  },
];

const releaseManagerPermissions: CapabilitySet = [
  { action: "read", scope: { org: "" }, delegable: false },
  { action: "review", scope: { org: "" }, delegable: false },
  { action: "approve", scope: { org: "" }, delegable: false },
  {
    action: "lifecycle.release",
    scope: { org: "", resource: "" },
    delegable: false,
  },
  {
    action: "lifecycle.publish",
    scope: { org: "", resource: "" },
    delegable: false,
  },
  {
    action: "disclosure.promote",
    scope: {
      org: "",
      resource: "",
      visibility: ["internal", "partner", "restricted-external", "public"],
    },
    delegable: false,
  },
  {
    action: "package.publish",
    scope: {
      org: "",
      resource: "",
      environment: ["staging", "production", "public-registry"],
    },
    delegable: false,
  },
];

/** Non-delegable release automation — HSM assurance enforced at PEP. */
const releaseBotPermissions: CapabilitySet = [
  {
    action: "package.release",
    scope: {
      org: "",
      resource: "",
      environment: ["production", "public-registry"],
    },
    delegable: false,
  },
  {
    action: "package.publish",
    scope: {
      org: "",
      resource: "",
      environment: ["production", "public-registry"],
    },
    delegable: false,
  },
  {
    action: "package.sign",
    scope: {
      org: "",
      resource: "",
      environment: ["production", "public-registry"],
    },
    delegable: false,
  },
  {
    action: "lifecycle.release",
    scope: { org: "", resource: "" },
    delegable: false,
  },
  {
    action: "lifecycle.publish",
    scope: { org: "", resource: "" },
    delegable: false,
  },
];

const ciServicePermissions: CapabilitySet = [
  { action: "read", scope: { org: "", resource: "" }, delegable: false },
  {
    action: "execute",
    scope: {
      org: "",
      resource: "",
      environment: ["development", "test", "staging"],
    },
    delegable: false,
  },
  {
    action: "package.publish",
    scope: {
      org: "",
      resource: "",
      environment: ["staging"],
    },
    delegable: false,
  },
  {
    action: "delegation.grant",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "package.sign",
    scope: {},
    delegable: false,
    effect: "deny",
  },
];

/** AI engineering agent — propose/execute only; never approve/sign/publish/delegate. */
const aiEngineeringAgentPermissions: CapabilitySet = [
  { action: "read", scope: { org: "", resource: "" }, delegable: false },
  {
    action: "propose",
    scope: {
      org: "",
      resource: "",
      semantic: ["urn:os20:semantic:behaviour", "urn:os20:semantic:design"],
      lifecycle: ["draft", "working"],
    },
    delegable: false,
  },
  {
    action: "execute",
    scope: {
      org: "",
      resource: "",
      semantic: ["urn:os20:semantic:simulation"],
    },
    delegable: false,
  },
  { action: "approve", scope: {}, delegable: false, effect: "deny" },
  { action: "attest", scope: {}, delegable: false, effect: "deny" },
  { action: "sign", scope: {}, delegable: false, effect: "deny" },
  { action: "package.sign", scope: {}, delegable: false, effect: "deny" },
  { action: "package.publish", scope: {}, delegable: false, effect: "deny" },
  { action: "publish", scope: {}, delegable: false, effect: "deny" },
  { action: "delegation.grant", scope: {}, delegable: false, effect: "deny" },
];

/** External supplier — partner visibility, limited semantics. */
const supplierEngineerPermissions: CapabilitySet = [
  {
    action: "read",
    scope: {
      org: "",
      resource: "",
      semantic: [
        "urn:os20:semantic:requirements",
        "urn:os20:semantic:documentation",
      ],
      visibility: ["partner"],
    },
    delegable: false,
  },
  {
    action: "property.read",
    scope: {
      org: "",
      resource: "",
      semantic: ["urn:os20:semantic:geometry"],
      visibility: ["partner"],
    },
    delegable: false,
  },
  {
    action: "modify",
    scope: {
      org: "",
      resource: "",
      semantic: ["urn:os20:semantic:compliance"],
      visibility: ["partner"],
      lifecycle: ["draft", "working"],
    },
    delegable: false,
  },
];

const auditorPermissions: CapabilitySet = [
  {
    action: "read",
    scope: { org: "", resource: "" },
    delegable: false,
  },
  {
    action: "discover",
    scope: { org: "", resource: "" },
    delegable: false,
  },
  {
    action: "relation.read",
    scope: { org: "", resource: "" },
    delegable: false,
  },
  { action: "modify", scope: {}, delegable: false, effect: "deny" },
  { action: "approve", scope: {}, delegable: false, effect: "deny" },
  { action: "publish", scope: {}, delegable: false, effect: "deny" },
];

export const CATALOG_SEED: CatalogSeed = {
  serviceId: SERVICE_ID,
  actions: OS20_ACTIONS,
  scopeDimensions: OS20_SCOPE_DIMENSIONS,
  profiles: [
    { profile: "organization_owner", permissions: organizationOwnerPermissions },
    { profile: "package_maintainer", permissions: packageMaintainerPermissions },
    { profile: "geometry_engineer", permissions: geometryEngineerPermissions },
    {
      profile: "simulation_engineer",
      permissions: simulationEngineerPermissions,
    },
    {
      profile: "validation_engineer",
      permissions: validationEngineerPermissions,
    },
    { profile: "release_manager", permissions: releaseManagerPermissions },
    { profile: "release_bot", permissions: releaseBotPermissions },
    { profile: "ci_service", permissions: ciServicePermissions },
    {
      profile: "ai_engineering_agent",
      permissions: aiEngineeringAgentPermissions,
    },
    { profile: "supplier_engineer", permissions: supplierEngineerPermissions },
    { profile: "auditor", permissions: auditorPermissions },
  ],
};

/**
 * Map OS20 API / registry entitlement JWT action names → catalog actions.
 * Used by server PEP when composing capability AND billing entitlement.
 */
export const ENTITLEMENT_ACTION_MAP = {
  package_read: "package.read",
  package_publish: "package.publish",
  package_sign: "package.sign",
  package_release: "package.release",
  graph_read: "read",
  graph_modify: "modify",
  relation_link: "relation.link",
  lifecycle_publish: "lifecycle.publish",
  delegation_grant: "delegation.grant",
} as const;

/** Commercial package codes for Billing seed (see BILLING_PACKAGES.md). */
export const OS20_PLAN_CODES = {
  team: "os20_team",
  enterprise: "os20_enterprise",
  regulated: "os20_regulated",
  partnerSeat: "os20_partner_seat",
  machineSeat: "os20_machine_seat",
  storageGb: "os20_storage_gb",
} as const;

/** Usage meters (org pays). */
export const OS20_METERS = {
  apiCalls: "os20.api.calls",
  storageBytes: "os20.storage.bytes",
  simulationSeconds: "os20.simulation.seconds",
  registryEgressBytes: "os20.registry.egress.bytes",
} as const;
