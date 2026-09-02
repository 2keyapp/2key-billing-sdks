/**
 * @2key/browser-sdk — unified browser client for AuthN + AuthZ + Billing.
 *
 * Native parity lives in private `2key-core-sdk` (Rust). This package is the
 * TypeScript / browser behavioral reference with the same product surface.
 *
 * Prefer subpath imports when you only need one pillar:
 * - `@2key/browser-sdk/auth` — AuthN adapters
 * - `@2key/browser-sdk/billing` — Billing (license, session, plans, usage)
 * - `@2key/browser-sdk/authorize` — pure AuthZ algebra
 * - `@2key/browser-sdk/dp` — DP Admin / Device / Machine AuthN HTTP
 */

// AuthN
export {
  acquireApiToken,
  portalHandoffUrl,
  authBaseUrl,
  portalPathUrl,
  resolvedPortalBaseUrl,
  shopUrl,
  socialSignInUrl,
  signInWithEmail,
  signUpWithEmail,
  fetchOAuthProviders,
  type AcquireApiTokenResult,
  type EmailAuthResult,
  type EmailAuthUser,
  type OAuthProviderInfo,
  type OAuthProvidersDocument,
} from "./auth/index.js";

// Billing
export {
  BillingApiClient,
  createBillingClient,
  BillingClient,
  normalizeApiBaseUrl,
  validateConfig,
  TwoKeyError,
  parseLicenseClaims,
  isSubscriptionActive,
  licenseEntitlements,
  licenseListsSki,
  verifyLicenseJwt,
  BrowserSessionManager,
  LicenseDeviceKeystore,
  localStorageSessionStore,
  memorySessionStore,
  parsePlan,
  reportUsage,
  type SdkConfig,
  type OfferingCatalog,
  type ErrorCode,
  type LicensePayload,
  type BillingSubscription,
  type PayingParty,
  type LicenseEntitlementsView,
  type LicenseDeviceIdentity,
  type SyncResult,
  type BootstrapResult,
  type FetchPlansQuery,
  type AccountSession,
  type SessionStore,
  type Plan,
  type UsageReportRequest,
  type UsageReportResult,
} from "./billing/index.js";

// AuthZ (pure algebra — same fixtures as Rust dp-rust)
export {
  actionCovers,
  assertAuthorized,
  assertSubset,
  authorize,
  dnsPrefixSubset,
  enforceLocally,
  expandProfile,
} from "@2key/dp-authorize";
export type {
  AuthorizeResult,
  EnforceInput,
  Resource,
  ScopeMap,
  SubsetResult,
} from "@2key/dp-authorize";

// DP clients + presentation (machine / admin)
export {
  createAdminClient,
  createEnrollClient,
  createMachineAuthnClient,
  createAgentTokenClient,
  attachPlatformCosign,
  verifyCredentialSignature,
  createDeviceIdentity,
  verifyPresentedCredential,
  generateEd25519KeyPair,
  randomLocalId,
  createInBandCredentialPresenter,
  parseDpCredentialFrame,
  DP_CREDENTIAL_FRAME_TYPE,
} from "@2key/dp-ts";
export type {
  AdminClient,
  AdminClientOptions,
  EnrollClient,
  EnrollClientOptions,
  EnrollDeviceParams,
  EnrollDeviceResult,
  KickstartRequest,
  MachineAuthnClient,
  MachineAuthnClientOptions,
  AgentTokenClient,
  AgentTokenClientOptions,
  AgentTokenMintRequest,
  AgentTokenMintResponse,
  KeyPairMaterial,
  CredentialPresenter,
  DeviceIdentity,
  DpCredentialFrame,
  MtlsClientMaterial,
  PepConnector,
  PepSession,
  CapabilityCredential,
  CapabilitySet,
  CatalogSeed,
} from "@2key/dp-ts";
