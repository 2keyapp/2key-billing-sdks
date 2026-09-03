/**
 * Admin-shaped wrapper over Machine AuthN HTTP (`createMachineAuthnClient`).
 */
import {
  createMachineAuthnClient,
  type MachineAuthnClientOptions,
} from "./machine-authn.js";
import type {
  CredentialListResult,
  CredentialRevokeRequest,
  CredentialRevokeResult,
  CredentialStatusResult,
  DeviceEnrollRequest,
  DeviceEnrollResult,
  EnrollApproveRequest,
  EnrollCreateResult,
  EnrollInstantRequest,
  EnrollListResult,
  EnrollRejectRequest,
  EnrollRejectResult,
  IssueCredentialResult,
  IssueDelegateRequest,
  IssueMachineRequest,
  MachineDecommissionRequest,
  MachineDecommissionResult,
  MachineRenewRequest,
  MachineRenewResult,
  PlatformRootResult,
  PublicJwk,
} from "@2key/dp-spec";
import type { DeviceIdentity } from "@2key/dp-presentation";
import { generateKeyAndCsr } from "@2key/dp-mtls";

export type AdminClientOptions = {
  /** Billing API v1 base URL, e.g. `https://auth.example.com/api/v1` */
  readonly baseURL: string;
  readonly fetch?: typeof fetch;
  readonly headers?: HeadersInit;
};

export type KickstartRequest = {
  readonly entityId: string;
  readonly package: "personal" | "enterprise";
  readonly publicJwk?: PublicJwk;
  readonly csrPem?: string;
};

/**
 * Admin-shaped Machine AuthN client. Prefer `createMachineAuthnClient` for new code.
 */
export function createAdminClient(options: AdminClientOptions) {
  const inner = createMachineAuthnClient({
    baseUrl: options.baseURL,
    fetch: options.fetch,
    headers: options.headers,
  });

  return {
    kickstartEntity(body: KickstartRequest): Promise<DeviceEnrollResult> {
      return inner.register(body as Record<string, unknown>) as Promise<DeviceEnrollResult>;
    },
    issueDelegate(body: IssueDelegateRequest): Promise<IssueCredentialResult> {
      return inner.issueDelegate(body as Record<string, unknown>) as Promise<IssueCredentialResult>;
    },
    issueMachine(body: IssueMachineRequest): Promise<IssueCredentialResult> {
      throw new Error("issue-machine removed — use enrollCreate");
    },
    enrollMachine(body: DeviceEnrollRequest): Promise<EnrollCreateResult> {
      return inner.enrollCreate(body as Record<string, unknown>) as Promise<EnrollCreateResult>;
    },
    enrollInstant(body: EnrollInstantRequest): Promise<DeviceEnrollResult> {
      throw new Error("enroll-instant not on billing server — use local ceremony + enrollApprove");
    },
    enrollPull(body: { pullToken: string }) {
      return inner.enrollPull(body) as Promise<DeviceEnrollResult & { status: string }>;
    },
    enrollApprove(body: EnrollApproveRequest): Promise<unknown> {
      return inner.enrollApprove(body as Record<string, unknown>);
    },
    enrollList(query: { entityId: string; status?: string }): Promise<EnrollListResult> {
      return inner.enrollList(query) as Promise<EnrollListResult>;
    },
    enrollReject(_body: EnrollRejectRequest): Promise<EnrollRejectResult> {
      throw new Error("enroll-reject not on billing server");
    },
    credentialRevoke(_body: CredentialRevokeRequest): Promise<CredentialRevokeResult> {
      throw new Error("credential-revoke not on billing server");
    },
    credentialStatus(query: { ski: string }): Promise<CredentialStatusResult> {
      return inner.credentialStatus(query) as Promise<CredentialStatusResult>;
    },
    credentialList(_query: { entityId: string; status?: string }): Promise<CredentialListResult> {
      throw new Error("credential-list not on billing server");
    },
    machineDecommission(_body: MachineDecommissionRequest): Promise<MachineDecommissionResult> {
      throw new Error("machine-decommission not on billing server");
    },
    machineRenew(body: MachineRenewRequest): Promise<MachineRenewResult> {
      return inner.machineRenew(body as Record<string, unknown>) as Promise<MachineRenewResult>;
    },
    platformRoot(): Promise<PlatformRootResult> {
      return inner.platformRoot() as Promise<PlatformRootResult>;
    },
  };
}

export type AdminClient = ReturnType<typeof createAdminClient>;

export type { MachineAuthnClientOptions };
export { createMachineAuthnClient } from "./machine-authn.js";

export type EnrollClientOptions = AdminClientOptions & {
  readonly enrollPath?: string;
};

export type EnrollDeviceParams = {
  readonly entityId: string;
  readonly commonName?: string;
  readonly host?: string;
  readonly kind?: DeviceEnrollRequest["kind"];
};

export type EnrollDeviceResult = {
  readonly ski: string;
  readonly publicJwk: PublicJwk;
  readonly privateJwk: Record<string, unknown>;
  readonly csrPem: string;
  readonly enrollment: EnrollCreateResult;
  readonly identity?: DeviceIdentity;
};

/** Device-side enroll composer (crypto in `@2key/dp-mtls`; HTTP via Machine AuthN). */
export function createEnrollClient(options: EnrollClientOptions) {
  const admin = createAdminClient(options);
  const enrollPath = options.enrollPath ?? "/machine-authn/enroll-create";

  async function postEnroll(body: DeviceEnrollRequest): Promise<EnrollCreateResult> {
    if (enrollPath === "/machine-authn/enroll-create") {
      return admin.enrollMachine(body);
    }
    const headers = new Headers(options.headers);
    headers.set("content-type", "application/json");
    const fetchImpl = options.fetch ?? globalThis.fetch;
    const res = await fetchImpl(new URL(enrollPath, options.baseURL), {
      method: "POST",
      headers,
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      const text = await res.text();
      throw new Error(`Device enroll request failed (${res.status}): ${text}`);
    }
    return (await res.json()) as EnrollCreateResult;
  }

  return {
    async enroll(params: EnrollDeviceParams): Promise<EnrollDeviceResult> {
      const { privateJwk, publicJwk, ski, csrPem } = await generateKeyAndCsr({
        commonName: params.commonName ?? params.entityId,
        ...(params.host !== undefined ? { host: params.host } : {}),
      });

      const request: DeviceEnrollRequest = {
        entityId: params.entityId,
        subjectSki: ski,
        publicJwk,
        csrPem,
        ...(params.host !== undefined ? { host: params.host } : {}),
        ...(params.kind !== undefined ? { kind: params.kind } : {}),
      };

      const enrollment = await postEnroll(request);
      const maybeCredential = (enrollment as unknown as Partial<DeviceEnrollResult>).credential;

      return {
        ski,
        publicJwk,
        privateJwk,
        csrPem,
        enrollment,
        ...(maybeCredential
          ? {
              identity: {
                ski,
                publicJwk,
                privateJwk,
                credential: maybeCredential,
              },
            }
          : {}),
      };
    },
  };
}

export type EnrollClient = ReturnType<typeof createEnrollClient>;
