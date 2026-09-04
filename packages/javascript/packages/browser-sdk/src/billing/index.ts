/**
 * Billing client — protocol parity with two-key-core (license, session, plans, usage).
 */
export {
  BillingApiClient,
  type SyncResult,
  type BootstrapResult,
  type FetchPlansQuery,
  type BindLicenseDeviceInput,
  type BindLicenseDeviceResult,
  type LicenseDevicePlatform,
} from "./api.js";
export {
  normalizeApiBaseUrl,
  validateConfig,
  type SdkConfig,
} from "./config.js";
export { TwoKeyError, type ErrorCode } from "./errors.js";
export {
  parseLicenseClaims,
  isSubscriptionActive,
  licenseEntitlements,
  licenseListsSki,
  type LicensePayload,
  type BillingSubscription,
  type PayingParty,
  type LicenseOfferingClaim,
  type LicenseDeviceClaim,
  type LicenseEntitlementsView,
} from "./license.js";
export { verifyLicenseJwt } from "./verify.js";
export {
  BrowserSessionManager,
  localStorageSessionStore,
  memorySessionStore,
  type AccountSession,
  type SessionStore,
} from "./session.js";
export { parsePlan, type Plan } from "./catalog.js";
export {
  type OfferingCatalog,
  catalogKnowsProduct,
  catalogKnowsOffering,
  catalogKnowsAddon,
} from "./offering-catalog.js";
export {
  LicenseDeviceKeystore,
  type LicenseDeviceIdentity,
} from "./device.js";
export {
  BillingClient,
  createBillingClient,
  DEFAULT_LICENSE_POLL_MS,
  type CreateBillingClientOptions,
} from "./client.js";
export {
  reportUsage,
  type UsageReportRequest,
  type UsageReportResult,
} from "./usage.js";
