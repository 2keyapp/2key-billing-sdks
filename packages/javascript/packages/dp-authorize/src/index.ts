export { actionCovers } from "./action.js";
export { authorize } from "./authorize.js";
export { expandProfile } from "./expand.js";
export { assertAuthorized, enforceLocally, type EnforceInput } from "./enforce.js";
export {
	dnsPrefixSubset,
	pathPrefixSubset,
	resourceSatisfiesScope,
	scopeMapSubset,
	scopesOverlapDeny,
	scopeValueSubset,
	scopeValuesOverlap,
} from "./scope.js";
export {
	isExactVersion,
	parseExactVersion,
	parseRangeToInterval,
	semverRangeSubset,
	semverRangesOverlap,
	semverSatisfies,
} from "./semver.js";
export { assertSubset } from "./subset.js";
export type {
	ActionDef,
	AuthorizeResult,
	Capability,
	CapabilityEffect,
	CapabilitySet,
	Catalog,
	ProfileDef,
	Resource,
	ScopeAlgebra,
	ScopeDimensionDef,
	ScopeMap,
	SubsetResult,
} from "./types.js";
export { effectOf } from "./types.js";
