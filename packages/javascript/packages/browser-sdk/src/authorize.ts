/** Re-export AuthZ algebra — `@2key/browser-sdk/authorize`. */
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
  CapabilitySet,
  Catalog,
} from "@2key/dp-authorize";
