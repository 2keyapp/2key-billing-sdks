import type { CapabilitySet, CatalogSeed } from "@2key/dp-spec";

/**
 * Stable serviceId / tenant slug for MnMs.
 * Wire: `delegatePermissions({ serviceId: SERVICE_ID, seed: CATALOG_SEED })`
 */
export const SERVICE_ID = "mnms";

/**
 * MnMs — multi-app DevOps control plane.
 *
 * App-owners own app trees and delegate attenuated CapabilitySets to Admins.
 * Admins may further subdelegate. The same human principal may hold grants from
 * many app-owners; the PEP unions those grants at authorize() time.
 *
 * Placement:
 * - API Gateway servers host app Containers
 * - Database servers host app Tablespaces
 *
 * DevOps families are discipline-prefixed actions + optional `discipline` scope.
 * Profiles are convenience bundles only — not RBAC primitives.
 *
 * Requires DP algebra v2 (`path_prefix`, optional `effect: "deny"`).
 * See README.md and BILLING_PACKAGES.md.
 */

export const MNMS_ENVIRONMENTS = [
  "dev",
  "test",
  "staging",
  "production",
] as const;

export const MNMS_DISCIPLINES = [
  "sysops",
  "netops",
  "secops",
  "dbaops",
  "mlops",
  "appdev",
  "dbdev",
] as const;

const MNMS_ACTIONS = [
  // --- Control plane / delegation ---
  { action: "entity.read", description: "Read entity control-plane metadata" },
  { action: "app.read", description: "Read app metadata and inventory" },
  { action: "app.manage", description: "Manage app settings under owned tree" },
  {
    action: "app.delegate",
    description: "Delegate app-scoped authority to admins",
  },
  { action: "delegation.grant", description: "Issue attenuated CapabilitySet" },
  {
    action: "delegation.revoke",
    description: "Revoke delegated CapabilitySet / subtree",
  },
  { action: "admin.invite", description: "Invite interim admin identity" },
  { action: "cert.issue", description: "Sign downstream capability credentials" },
  { action: "machine.bind", description: "Bind CI/bot machine principal" },
  { action: "seat.bind", description: "Bind permanent machine seat in Billing" },

  // --- SysOps ---
  { action: "sysops.host.read", description: "Read host / server inventory" },
  { action: "sysops.host.reboot", description: "Reboot host" },
  {
    action: "sysops.package.install",
    description: "Install/update host packages",
  },
  {
    action: "sysops.container.read",
    description: "Read container status on API GW",
  },
  {
    action: "sysops.container.start",
    description: "Start app container",
  },
  { action: "sysops.container.stop", description: "Stop app container" },
  {
    action: "sysops.container.exec",
    description: "Exec into container (high risk)",
  },
  { action: "sysops.container.logs", description: "Read container logs" },
  { action: "sysops.container.scale", description: "Scale container replicas" },
  {
    action: "sysops.container.deploy",
    description: "Deploy/replace container image",
  },

  // --- NetOps ---
  { action: "netops.route.read", description: "Read routes" },
  { action: "netops.route.modify", description: "Modify routes" },
  { action: "netops.firewall.read", description: "Read firewall rules" },
  { action: "netops.firewall.modify", description: "Modify firewall rules" },
  { action: "netops.lb.read", description: "Read load-balancer config" },
  { action: "netops.lb.modify", description: "Modify load-balancer config" },
  { action: "netops.dns.read", description: "Read DNS records" },
  { action: "netops.dns.modify", description: "Modify DNS records" },

  // --- SecOps ---
  { action: "secops.policy.read", description: "Read security policy" },
  { action: "secops.policy.modify", description: "Modify security policy" },
  {
    action: "secops.secret.read",
    description: "Read secret material (distinct from rotate)",
  },
  { action: "secops.secret.rotate", description: "Rotate secrets" },
  { action: "secops.audit.read", description: "Read security audit logs" },
  { action: "secops.scan.run", description: "Run vulnerability / compliance scan" },
  {
    action: "secops.incident.manage",
    description: "Manage security incidents",
  },

  // --- DBAOps ---
  {
    action: "dbaops.tablespace.read",
    description: "Read tablespace metadata/usage",
  },
  {
    action: "dbaops.tablespace.create",
    description: "Create tablespace for an app",
  },
  {
    action: "dbaops.tablespace.resize",
    description: "Resize tablespace",
  },
  { action: "dbaops.backup.run", description: "Run database backup" },
  { action: "dbaops.backup.restore", description: "Restore from backup" },
  { action: "dbaops.user.grant", description: "Grant DB roles/users" },
  { action: "dbaops.user.revoke", description: "Revoke DB roles/users" },
  {
    action: "dbaops.migration.apply",
    description: "Apply DBA-owned migrations",
  },
  {
    action: "dbaops.replication.manage",
    description: "Manage replication topology",
  },

  // --- MLOps ---
  { action: "mlops.model.read", description: "Read model registry metadata" },
  { action: "mlops.model.deploy", description: "Deploy model serving" },
  { action: "mlops.model.rollback", description: "Rollback model serving" },
  { action: "mlops.pipeline.run", description: "Run ML pipeline" },
  {
    action: "mlops.featurestore.read",
    description: "Read feature store",
  },
  {
    action: "mlops.featurestore.write",
    description: "Write feature store",
  },

  // --- AppDev ---
  { action: "appdev.code.read", description: "Read application source" },
  { action: "appdev.code.push", description: "Push application source" },
  { action: "appdev.build.run", description: "Run application build" },
  {
    action: "appdev.deploy.staging",
    description: "Deploy app to staging",
  },
  {
    action: "appdev.deploy.production",
    description: "Deploy app to production (not implied by staging)",
  },
  { action: "appdev.config.read", description: "Read app config" },
  { action: "appdev.config.modify", description: "Modify app config" },
  {
    action: "appdev.container.logs",
    description: "Read app container logs (no exec)",
  },
  {
    action: "appdev.container.restart",
    description: "Restart app container (no exec)",
  },

  // --- DBDev ---
  { action: "dbdev.schema.read", description: "Read DB schema" },
  { action: "dbdev.schema.modify", description: "Modify DB schema" },
  { action: "dbdev.query.run", description: "Run ad-hoc queries" },
  {
    action: "dbdev.migration.propose",
    description: "Propose schema migration",
  },
  {
    action: "dbdev.migration.apply",
    description: "Apply developer migration (env-scoped)",
  },
  {
    action: "dbdev.tablespace.read",
    description: "Read tablespace info (not resize)",
  },
] as const;

const MNMS_SCOPE_DIMENSIONS = [
  { dimension: "entity", algebra: "exact" as const },
  /** App-owner → app → component tree, e.g. @acme/payments/api */
  { dimension: "app", algebra: "path_prefix" as const },
  /** Infra placement, e.g. gw/us-east/gw-01 or db/us-east/pg-03 */
  { dimension: "server", algebra: "path_prefix" as const },
  /** Container under app on API GW, e.g. @acme/payments/web */
  { dimension: "container", algebra: "path_prefix" as const },
  /** Tablespace under app on DB server, e.g. @acme/payments/ts_main */
  { dimension: "tablespace", algebra: "path_prefix" as const },
  { dimension: "environment", algebra: "set" as const },
  {
    dimension: "discipline",
    algebra: "set" as const,
  },
] as const;

const allEnvs = [...MNMS_ENVIRONMENTS];
const nonProdEnvs = ["dev", "test", "staging"] as const;

// --- Profiles ---

/** App-owner — full authority over owned app tree; can delegate. */
const appOwnerPermissions: CapabilitySet = [
  { action: "entity.read", scope: {}, delegable: true },
  { action: "app.read", scope: { app: "" }, delegable: true },
  { action: "app.manage", scope: { app: "" }, delegable: true },
  { action: "app.delegate", scope: { app: "" }, delegable: true },
  { action: "delegation.grant", scope: { app: "" }, delegable: true },
  { action: "delegation.revoke", scope: { app: "" }, delegable: true },
  { action: "admin.invite", scope: {}, delegable: true },
  { action: "cert.issue", scope: { app: "" }, delegable: true },
  { action: "machine.bind", scope: { app: "" }, delegable: true },
  { action: "seat.bind", scope: {}, delegable: true },
  // Discipline wildcards issued as concrete actions at seed — owners get all families
  { action: "sysops.host.read", scope: { app: "" }, delegable: true },
  { action: "sysops.host.reboot", scope: { app: "" }, delegable: true },
  { action: "sysops.package.install", scope: { app: "" }, delegable: true },
  { action: "sysops.container.read", scope: { app: "" }, delegable: true },
  { action: "sysops.container.start", scope: { app: "" }, delegable: true },
  { action: "sysops.container.stop", scope: { app: "" }, delegable: true },
  { action: "sysops.container.exec", scope: { app: "" }, delegable: true },
  { action: "sysops.container.logs", scope: { app: "" }, delegable: true },
  { action: "sysops.container.scale", scope: { app: "" }, delegable: true },
  { action: "sysops.container.deploy", scope: { app: "" }, delegable: true },
  { action: "netops.route.read", scope: { app: "" }, delegable: true },
  { action: "netops.route.modify", scope: { app: "" }, delegable: true },
  { action: "netops.firewall.read", scope: { app: "" }, delegable: true },
  { action: "netops.firewall.modify", scope: { app: "" }, delegable: true },
  { action: "netops.lb.read", scope: { app: "" }, delegable: true },
  { action: "netops.lb.modify", scope: { app: "" }, delegable: true },
  { action: "netops.dns.read", scope: { app: "" }, delegable: true },
  { action: "netops.dns.modify", scope: { app: "" }, delegable: true },
  { action: "secops.policy.read", scope: { app: "" }, delegable: true },
  { action: "secops.policy.modify", scope: { app: "" }, delegable: true },
  { action: "secops.secret.read", scope: { app: "" }, delegable: true },
  { action: "secops.secret.rotate", scope: { app: "" }, delegable: true },
  { action: "secops.audit.read", scope: { app: "" }, delegable: true },
  { action: "secops.scan.run", scope: { app: "" }, delegable: true },
  { action: "secops.incident.manage", scope: { app: "" }, delegable: true },
  { action: "dbaops.tablespace.read", scope: { app: "" }, delegable: true },
  { action: "dbaops.tablespace.create", scope: { app: "" }, delegable: true },
  { action: "dbaops.tablespace.resize", scope: { app: "" }, delegable: true },
  { action: "dbaops.backup.run", scope: { app: "" }, delegable: true },
  { action: "dbaops.backup.restore", scope: { app: "" }, delegable: true },
  { action: "dbaops.user.grant", scope: { app: "" }, delegable: true },
  { action: "dbaops.user.revoke", scope: { app: "" }, delegable: true },
  { action: "dbaops.migration.apply", scope: { app: "" }, delegable: true },
  { action: "dbaops.replication.manage", scope: { app: "" }, delegable: true },
  { action: "mlops.model.read", scope: { app: "" }, delegable: true },
  { action: "mlops.model.deploy", scope: { app: "" }, delegable: true },
  { action: "mlops.model.rollback", scope: { app: "" }, delegable: true },
  { action: "mlops.pipeline.run", scope: { app: "" }, delegable: true },
  { action: "mlops.featurestore.read", scope: { app: "" }, delegable: true },
  { action: "mlops.featurestore.write", scope: { app: "" }, delegable: true },
  { action: "appdev.code.read", scope: { app: "" }, delegable: true },
  { action: "appdev.code.push", scope: { app: "" }, delegable: true },
  { action: "appdev.build.run", scope: { app: "" }, delegable: true },
  { action: "appdev.deploy.staging", scope: { app: "" }, delegable: true },
  { action: "appdev.deploy.production", scope: { app: "" }, delegable: true },
  { action: "appdev.config.read", scope: { app: "" }, delegable: true },
  { action: "appdev.config.modify", scope: { app: "" }, delegable: true },
  { action: "appdev.container.logs", scope: { app: "" }, delegable: true },
  { action: "appdev.container.restart", scope: { app: "" }, delegable: true },
  { action: "dbdev.schema.read", scope: { app: "" }, delegable: true },
  { action: "dbdev.schema.modify", scope: { app: "" }, delegable: true },
  { action: "dbdev.query.run", scope: { app: "" }, delegable: true },
  { action: "dbdev.migration.propose", scope: { app: "" }, delegable: true },
  { action: "dbdev.migration.apply", scope: { app: "" }, delegable: true },
  { action: "dbdev.tablespace.read", scope: { app: "" }, delegable: true },
];

/**
 * Platform Admin under an app — broad DevOps; can subdelegate within app.
 * Narrow `app` at issue time (e.g. @acme/payments).
 */
const adminPermissions: CapabilitySet = [
  { action: "app.read", scope: { app: "" }, delegable: true },
  { action: "delegation.grant", scope: { app: "" }, delegable: true },
  { action: "delegation.revoke", scope: { app: "" }, delegable: false },
  { action: "sysops.container.read", scope: { app: "" }, delegable: true },
  { action: "sysops.container.start", scope: { app: "" }, delegable: true },
  { action: "sysops.container.stop", scope: { app: "" }, delegable: true },
  { action: "sysops.container.logs", scope: { app: "" }, delegable: true },
  { action: "sysops.container.scale", scope: { app: "" }, delegable: true },
  { action: "sysops.container.deploy", scope: { app: "" }, delegable: true },
  {
    action: "sysops.container.exec",
    scope: { app: "", environment: [...nonProdEnvs] },
    delegable: false,
  },
  { action: "netops.route.read", scope: { app: "" }, delegable: true },
  { action: "netops.lb.read", scope: { app: "" }, delegable: true },
  { action: "netops.lb.modify", scope: { app: "" }, delegable: true },
  { action: "secops.policy.read", scope: { app: "" }, delegable: true },
  { action: "secops.audit.read", scope: { app: "" }, delegable: true },
  { action: "secops.scan.run", scope: { app: "" }, delegable: true },
  { action: "secops.secret.rotate", scope: { app: "" }, delegable: false },
  { action: "dbaops.tablespace.read", scope: { app: "" }, delegable: true },
  { action: "dbaops.backup.run", scope: { app: "" }, delegable: true },
  { action: "appdev.code.read", scope: { app: "" }, delegable: true },
  { action: "appdev.build.run", scope: { app: "" }, delegable: true },
  { action: "appdev.deploy.staging", scope: { app: "" }, delegable: true },
  {
    action: "appdev.deploy.production",
    scope: { app: "" },
    delegable: false,
  },
  { action: "appdev.container.logs", scope: { app: "" }, delegable: true },
  { action: "appdev.container.restart", scope: { app: "" }, delegable: true },
  { action: "dbdev.schema.read", scope: { app: "" }, delegable: true },
  { action: "dbdev.migration.propose", scope: { app: "" }, delegable: true },
];

const sysopsPermissions: CapabilitySet = [
  {
    action: "sysops.host.read",
    scope: { app: "", discipline: ["sysops"] },
    delegable: false,
  },
  {
    action: "sysops.container.read",
    scope: { app: "", container: "", discipline: ["sysops"] },
    delegable: false,
  },
  {
    action: "sysops.container.start",
    scope: { app: "", container: "", discipline: ["sysops"] },
    delegable: false,
  },
  {
    action: "sysops.container.stop",
    scope: { app: "", container: "", discipline: ["sysops"] },
    delegable: false,
  },
  {
    action: "sysops.container.logs",
    scope: { app: "", container: "", discipline: ["sysops"] },
    delegable: false,
  },
  {
    action: "sysops.container.scale",
    scope: { app: "", container: "", discipline: ["sysops"] },
    delegable: false,
  },
  {
    action: "sysops.container.deploy",
    scope: {
      app: "",
      container: "",
      environment: [...nonProdEnvs],
      discipline: ["sysops"],
    },
    delegable: false,
  },
  {
    action: "delegation.grant",
    scope: {},
    delegable: false,
    effect: "deny",
  },
];

const netopsPermissions: CapabilitySet = [
  {
    action: "netops.route.read",
    scope: { app: "", discipline: ["netops"] },
    delegable: false,
  },
  {
    action: "netops.route.modify",
    scope: { app: "", discipline: ["netops"] },
    delegable: false,
  },
  {
    action: "netops.firewall.read",
    scope: { app: "", discipline: ["netops"] },
    delegable: false,
  },
  {
    action: "netops.firewall.modify",
    scope: {
      app: "",
      environment: [...nonProdEnvs],
      discipline: ["netops"],
    },
    delegable: false,
  },
  {
    action: "netops.lb.read",
    scope: { app: "", discipline: ["netops"] },
    delegable: false,
  },
  {
    action: "netops.lb.modify",
    scope: { app: "", discipline: ["netops"] },
    delegable: false,
  },
  {
    action: "netops.dns.read",
    scope: { app: "", discipline: ["netops"] },
    delegable: false,
  },
  {
    action: "delegation.grant",
    scope: {},
    delegable: false,
    effect: "deny",
  },
];

const secopsPermissions: CapabilitySet = [
  {
    action: "secops.policy.read",
    scope: { app: "", discipline: ["secops"] },
    delegable: false,
  },
  {
    action: "secops.audit.read",
    scope: { app: "", discipline: ["secops"] },
    delegable: false,
  },
  {
    action: "secops.scan.run",
    scope: { app: "", discipline: ["secops"] },
    delegable: false,
  },
  {
    action: "secops.secret.rotate",
    scope: { app: "", discipline: ["secops"] },
    delegable: false,
  },
  {
    action: "secops.incident.manage",
    scope: { app: "", discipline: ["secops"] },
    delegable: false,
  },
  {
    action: "secops.secret.read",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "delegation.grant",
    scope: {},
    delegable: false,
    effect: "deny",
  },
];

const dbaopsPermissions: CapabilitySet = [
  {
    action: "dbaops.tablespace.read",
    scope: { app: "", tablespace: "", discipline: ["dbaops"] },
    delegable: false,
  },
  {
    action: "dbaops.tablespace.resize",
    scope: { app: "", tablespace: "", discipline: ["dbaops"] },
    delegable: false,
  },
  {
    action: "dbaops.backup.run",
    scope: { app: "", tablespace: "", discipline: ["dbaops"] },
    delegable: false,
  },
  {
    action: "dbaops.backup.restore",
    scope: {
      app: "",
      tablespace: "",
      environment: [...nonProdEnvs],
      discipline: ["dbaops"],
    },
    delegable: false,
  },
  {
    action: "dbaops.user.grant",
    scope: { app: "", discipline: ["dbaops"] },
    delegable: false,
  },
  {
    action: "dbaops.user.revoke",
    scope: { app: "", discipline: ["dbaops"] },
    delegable: false,
  },
  {
    action: "dbaops.replication.manage",
    scope: { app: "", discipline: ["dbaops"] },
    delegable: false,
  },
  {
    action: "delegation.grant",
    scope: {},
    delegable: false,
    effect: "deny",
  },
];

const mlopsPermissions: CapabilitySet = [
  {
    action: "mlops.model.read",
    scope: { app: "", discipline: ["mlops"] },
    delegable: false,
  },
  {
    action: "mlops.model.deploy",
    scope: {
      app: "",
      environment: [...nonProdEnvs],
      discipline: ["mlops"],
    },
    delegable: false,
  },
  {
    action: "mlops.pipeline.run",
    scope: { app: "", discipline: ["mlops"] },
    delegable: false,
  },
  {
    action: "mlops.featurestore.read",
    scope: { app: "", discipline: ["mlops"] },
    delegable: false,
  },
  {
    action: "mlops.featurestore.write",
    scope: {
      app: "",
      environment: [...nonProdEnvs],
      discipline: ["mlops"],
    },
    delegable: false,
  },
  {
    action: "delegation.grant",
    scope: {},
    delegable: false,
    effect: "deny",
  },
];

const appdevPermissions: CapabilitySet = [
  {
    action: "appdev.code.read",
    scope: { app: "", discipline: ["appdev"] },
    delegable: false,
  },
  {
    action: "appdev.code.push",
    scope: { app: "", discipline: ["appdev"] },
    delegable: false,
  },
  {
    action: "appdev.build.run",
    scope: { app: "", discipline: ["appdev"] },
    delegable: false,
  },
  {
    action: "appdev.deploy.staging",
    scope: {
      app: "",
      environment: ["staging"],
      discipline: ["appdev"],
    },
    delegable: false,
  },
  {
    action: "appdev.config.read",
    scope: { app: "", discipline: ["appdev"] },
    delegable: false,
  },
  {
    action: "appdev.config.modify",
    scope: {
      app: "",
      environment: [...nonProdEnvs],
      discipline: ["appdev"],
    },
    delegable: false,
  },
  {
    action: "appdev.container.logs",
    scope: { app: "", container: "", discipline: ["appdev"] },
    delegable: false,
  },
  {
    action: "appdev.container.restart",
    scope: {
      app: "",
      container: "",
      environment: [...nonProdEnvs],
      discipline: ["appdev"],
    },
    delegable: false,
  },
  {
    action: "appdev.deploy.production",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "sysops.container.exec",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "delegation.grant",
    scope: {},
    delegable: false,
    effect: "deny",
  },
];

const dbdevPermissions: CapabilitySet = [
  {
    action: "dbdev.schema.read",
    scope: { app: "", discipline: ["dbdev"] },
    delegable: false,
  },
  {
    action: "dbdev.schema.modify",
    scope: {
      app: "",
      environment: [...nonProdEnvs],
      discipline: ["dbdev"],
    },
    delegable: false,
  },
  {
    action: "dbdev.query.run",
    scope: {
      app: "",
      environment: [...nonProdEnvs],
      discipline: ["dbdev"],
    },
    delegable: false,
  },
  {
    action: "dbdev.migration.propose",
    scope: { app: "", discipline: ["dbdev"] },
    delegable: false,
  },
  {
    action: "dbdev.migration.apply",
    scope: {
      app: "",
      environment: [...nonProdEnvs],
      discipline: ["dbdev"],
    },
    delegable: false,
  },
  {
    action: "dbdev.tablespace.read",
    scope: { app: "", tablespace: "", discipline: ["dbdev"] },
    delegable: false,
  },
  {
    action: "dbaops.tablespace.resize",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "delegation.grant",
    scope: {},
    delegable: false,
    effect: "deny",
  },
];

const auditorPermissions: CapabilitySet = [
  { action: "app.read", scope: { app: "" }, delegable: false },
  { action: "sysops.container.read", scope: { app: "" }, delegable: false },
  { action: "sysops.container.logs", scope: { app: "" }, delegable: false },
  { action: "dbaops.tablespace.read", scope: { app: "" }, delegable: false },
  { action: "secops.audit.read", scope: { app: "" }, delegable: false },
  { action: "secops.policy.read", scope: { app: "" }, delegable: false },
  {
    action: "sysops.container.exec",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "delegation.grant",
    scope: {},
    delegable: false,
    effect: "deny",
  },
];

const ciBotPermissions: CapabilitySet = [
  {
    action: "appdev.build.run",
    scope: { app: "", environment: [...allEnvs] },
    delegable: false,
  },
  {
    action: "appdev.deploy.staging",
    scope: { app: "", environment: ["staging"] },
    delegable: false,
  },
  {
    action: "sysops.container.logs",
    scope: { app: "", environment: [...nonProdEnvs] },
    delegable: false,
  },
  {
    action: "appdev.deploy.production",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "delegation.grant",
    scope: {},
    delegable: false,
    effect: "deny",
  },
  {
    action: "sysops.container.exec",
    scope: {},
    delegable: false,
    effect: "deny",
  },
];

export const CATALOG_SEED: CatalogSeed = {
  serviceId: SERVICE_ID,
  actions: MNMS_ACTIONS,
  scopeDimensions: MNMS_SCOPE_DIMENSIONS,
  profiles: [
    { profile: "app_owner", permissions: appOwnerPermissions },
    { profile: "admin", permissions: adminPermissions },
    { profile: "sysops", permissions: sysopsPermissions },
    { profile: "netops", permissions: netopsPermissions },
    { profile: "secops", permissions: secopsPermissions },
    { profile: "dbaops", permissions: dbaopsPermissions },
    { profile: "mlops", permissions: mlopsPermissions },
    { profile: "appdev", permissions: appdevPermissions },
    { profile: "dbdev", permissions: dbdevPermissions },
    { profile: "auditor", permissions: auditorPermissions },
    { profile: "ci_bot", permissions: ciBotPermissions },
  ],
};

/**
 * Map MnMs control-plane / gateway entitlement JWT actions → catalog actions.
 */
export const ENTITLEMENT_ACTION_MAP = {
  container_start: "sysops.container.start",
  container_stop: "sysops.container.stop",
  container_deploy: "sysops.container.deploy",
  container_logs: "sysops.container.logs",
  tablespace_read: "dbaops.tablespace.read",
  tablespace_resize: "dbaops.tablespace.resize",
  backup_run: "dbaops.backup.run",
  app_deploy_staging: "appdev.deploy.staging",
  app_deploy_production: "appdev.deploy.production",
  delegation_grant: "delegation.grant",
} as const;

/** Commercial package codes for Billing seed. */
export const MNMS_PLAN_CODES = {
  starter: "mnms_starter",
  team: "mnms_team",
  enterprise: "mnms_enterprise",
  contractorSeat: "mnms_contractor_seat",
  machineSeat: "mnms_machine_seat",
} as const;

/** Usage meters (app-owner org pays). */
export const MNMS_METERS = {
  apiCalls: "mnms.api.calls",
  containerMinutes: "mnms.container.minutes",
  tablespaceBytes: "mnms.tablespace.bytes",
  backupBytes: "mnms.backup.bytes",
} as const;
