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

export {
  createMachineAuthnClient,
  type MachineAuthnClient,
  type MachineAuthnClientOptions,
} from "./machine-authn.js";
export {
  createAgentTokenClient,
  type AgentTokenClient,
  type AgentTokenClientOptions,
  type AgentTokenMintRequest,
  type AgentTokenMintResponse,
} from "./agent-token.js";
export { createAdminClient, createEnrollClient } from "./admin.js";
export type {
  AdminClient,
  AdminClientOptions,
  EnrollClient,
  EnrollClientOptions,
  EnrollDeviceParams,
  EnrollDeviceResult,
  KickstartRequest,
} from "./admin.js";
export {
  attachPlatformCosign,
  verifyCredentialSignature,
} from "./credential.js";
export {
  createDeviceIdentity,
  verifyPresentedCredential,
} from "./device.js";
export { generateEd25519KeyPair, randomLocalId } from "./keys.js";
export type { KeyPairMaterial } from "./keys.js";
export {
  createInBandCredentialPresenter,
  parseDpCredentialFrame,
  DP_CREDENTIAL_FRAME_TYPE,
} from "@2key/dp-presentation";
export type {
  CredentialPresenter,
  DeviceIdentity,
  DpCredentialFrame,
  MtlsClientMaterial,
  PepConnector,
  PepSession,
} from "@2key/dp-presentation";
export type {
  CapabilityCredential,
  CapabilitySet,
  CatalogSeed,
  CredentialListResult,
  CredentialRevokeResult,
  CredentialStatusResult,
  DeviceEnrollRequest,
  DeviceEnrollResult,
  EnrollCreateResult,
  IssueCredentialResult,
  IssueDelegateRequest,
  IssueMachineRequest,
  MachineDecommissionResult,
  MachineRenewResult,
  PlatformCosign,
} from "@2key/dp-spec";
