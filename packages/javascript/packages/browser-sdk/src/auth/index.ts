/**
 * AuthN client adapters for the browser (Better Auth cookie / redirect).
 * Engine stays in the better-auth fork; this is the host-facing client surface.
 */
export {
  acquireApiToken,
  acquireUsingPartyApiToken,
  bindOrganization,
  exchangeOneTimeToken,
  isOrgSlugRequiredBody,
  portalHandoffUrl,
  PERSONAL_ORG_SLUG,
  type AcquireApiTokenResult,
  type AuthSessionOpts,
  type BindOrganizationResult,
} from "./auth.js";
export { clearAuthSessionToken, readAuthSessionToken, saveAuthSessionToken } from "./auth-session-store.js";
export {
  authBaseUrl,
  officeSocialStartUrl,
  portalPathUrl,
  resolvedPortalBaseUrl,
  shopUrl,
  socialSignInUrl,
} from "./portal.js";
export {
  signInWithEmail,
  signUpWithEmail,
  fetchOAuthProviders,
  type EmailAuthResult,
  type EmailAuthUser,
  type OAuthProviderInfo,
  type OAuthProvidersDocument,
} from "./email.js";
