/**
 * AuthN client adapters for the browser (Better Auth cookie / redirect).
 * Engine stays in the better-auth fork; this is the host-facing client surface.
 */
export {
  acquireApiToken,
  portalHandoffUrl,
  type AcquireApiTokenResult,
} from "./auth.js";
export {
  authBaseUrl,
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
