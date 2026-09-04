import { BillingApiClient, type BindLicenseDeviceResult } from "./api.js";
import { validateConfig, type SdkConfig } from "./config.js";
import {
  LicenseDeviceKeystore,
  withFriendlyName,
  type LicenseDeviceIdentity,
} from "./device.js";
import { TwoKeyError } from "./errors.js";
import {
  licenseEntitlements,
  licenseListsSki,
  type LicenseEntitlementsView,
  type LicensePayload,
} from "./license.js";
import {
  BrowserSessionManager,
  memorySessionStore,
  type AccountSession,
  type SessionStore,
} from "./session.js";
import { verifyLicenseJwt } from "./verify.js";

const DEFAULT_ACCOUNT = "default";
/** Default background license poll interval (6 hours). */
export const DEFAULT_LICENSE_POLL_MS = 6 * 60 * 60 * 1000;

export type CreateBillingClientOptions = {
  store?: SessionStore;
  fetchImpl?: typeof fetch;
  accountKey?: string;
};

/**
 * Using-party billing client: DeviceID + license restore/sync + catalog gates.
 * Behavioral parity with Dart `LicenseDeviceKeystore` + `BillingSession` + `LicenseEntitlements`.
 */
export class BillingClient {
  readonly config: SdkConfig;
  readonly api: BillingApiClient;
  readonly session: BrowserSessionManager;
  readonly devices: LicenseDeviceKeystore;

  private payload: LicensePayload | null = null;
  private accountKey: string;
  private pollTimer: ReturnType<typeof setInterval> | null = null;

  constructor(config: SdkConfig, opts: CreateBillingClientOptions = {}) {
    this.config = validateConfig(config);
    const store = opts.store ?? memorySessionStore();
    this.api = new BillingApiClient(this.config, opts.fetchImpl ?? fetch.bind(globalThis));
    this.session = new BrowserSessionManager(this.config, store);
    this.devices = new LicenseDeviceKeystore(store, this.config.storagePrefix);
    this.accountKey = opts.accountKey?.trim() || DEFAULT_ACCOUNT;
  }

  setAccountKey(accountKey: string): void {
    this.accountKey = accountKey.trim() || DEFAULT_ACCOUNT;
  }

  /**
   * Create or load the local license-device identity (Ed25519 + SKI).
   */
  async ensureDeviceId(opts?: {
    accountKey?: string;
    friendlyName?: string;
  }): Promise<LicenseDeviceIdentity> {
    const key = opts?.accountKey?.trim() || this.accountKey;
    const identity = withFriendlyName(await this.devices.ensureForAccount(key), opts?.friendlyName);
    if (opts?.friendlyName?.trim()) {
      await this.devices.persistForAccount(key, identity);
    }
    return identity;
  }

  /** Verify a cached license JWT and paint gates immediately. */
  async restore(accountKey?: string): Promise<LicensePayload | null> {
    const key = accountKey?.trim() || this.accountKey;
    const stored = await this.session.load(key);
    if (!stored?.licenseJwt) {
      // Keep a just-synced in-memory license when persist has not flushed yet
      // (Outlook WebViews often no-op or delay localStorage).
      return this.payload;
    }
    try {
      this.payload = await verifyLicenseJwt(stored.licenseJwt, this.config.publicKeyPem);
      return this.payload;
    } catch {
      return this.payload;
    }
  }

  /** Verify a pasted license JWT and persist it. */
  async pasteLicense(jwt: string, accountKey?: string): Promise<LicensePayload> {
    const key = accountKey?.trim() || this.accountKey;
    const payload = await verifyLicenseJwt(jwt, this.config.publicKeyPem);
    this.payload = payload;
    const current = (await this.session.load(key)) ?? { accountKey: key };
    await this.session.save({ ...current, accountKey: key, licenseJwt: jwt.trim() });
    return payload;
  }

  /**
   * Bind the local device when unbound, then GET `/api/v1/license` (ETag when cached).
   */
  async syncLicense(opts: {
    accessToken: string;
    accountKey?: string;
    payingPartyId?: string;
    replaceSki?: string;
    bindIfNeeded?: boolean;
    useCachedEtag?: boolean;
    friendlyName?: string;
    platform?: "web" | "ios" | "android" | "desktop" | "unknown";
  }): Promise<LicensePayload> {
    const key = opts.accountKey?.trim() || this.accountKey;
    const stored = (await this.session.load(key)) ?? { accountKey: key };
    const device = await this.ensureDeviceId({
      accountKey: key,
      friendlyName: opts.friendlyName,
    });

    const bindIfNeeded = opts.bindIfNeeded !== false;
    if (bindIfNeeded && !licenseListsSki(this.payload, device.ski)) {
      const bound = await this.bindAndMaybeIssue(opts.accessToken, device, opts);
      if (bound) {
        await this.persistVerified(key, stored, bound.payload, bound.jwt, bound.etag);
        return bound.payload;
      }
    }

    const ifNoneMatch = opts.useCachedEtag === false ? undefined : stored.licenseEtag;
    const result = await this.api.fetchLicense({
      accessToken: opts.accessToken,
      payingPartyId: opts.payingPartyId ?? stored.payingPartyIdHeader,
      ifNoneMatch,
    });

    if (result.kind === "not_modified") {
      if (!this.payload && stored.licenseJwt) {
        this.payload = await verifyLicenseJwt(stored.licenseJwt, this.config.publicKeyPem);
      }
      if (!this.payload) {
        throw new TwoKeyError("not_modified", "License unchanged but no cached JWT is usable.");
      }
      await this.session.save({
        ...stored,
        accountKey: key,
        accessToken: opts.accessToken,
        licenseEtag: result.etag ?? stored.licenseEtag,
      });
      this.assertLocalDevice(device.ski);
      return this.payload;
    }

    const payload = await verifyLicenseJwt(result.signedToken, this.config.publicKeyPem);
    await this.persistVerified(key, stored, payload, result.signedToken, result.etag, opts.accessToken, opts.payingPartyId);
    this.assertLocalDevice(device.ski);
    return payload;
  }

  entitlements(nowUnix?: number): LicenseEntitlementsView {
    if (!this.payload) {
      throw new TwoKeyError("license_malformed", "No verified license. Call restore() or syncLicense() first.");
    }
    return licenseEntitlements(this.payload, nowUnix, this.config.catalog);
  }

  hasProduct(productId: string): boolean {
    return this.entitlements().hasProduct(productId);
  }

  hasOffering(offeringCode: string): boolean {
    return this.entitlements().hasOffering(offeringCode);
  }

  hasAddon(addonCode: string): boolean {
    return this.entitlements().hasAddon(addonCode);
  }

  startPolling(opts: {
    accessToken: () => string | Promise<string>;
    intervalMs?: number;
    accountKey?: string;
  }): void {
    this.stopPolling();
    const interval = opts.intervalMs ?? DEFAULT_LICENSE_POLL_MS;
    this.pollTimer = setInterval(() => {
      void (async () => {
        try {
          const token = await opts.accessToken();
          if (!token.trim()) return;
          await this.syncLicense({
            accessToken: token,
            accountKey: opts.accountKey,
            useCachedEtag: true,
            bindIfNeeded: false,
          });
        } catch {
          /* skip this tick — task pane may be signed out */
        }
      })();
    }, interval);
  }

  stopPolling(): void {
    if (this.pollTimer) {
      clearInterval(this.pollTimer);
      this.pollTimer = null;
    }
  }

  private assertLocalDevice(ski: string): void {
    if (!this.payload) return;
    if (!licenseEntitlements(this.payload).allowsDevice(ski)) {
      throw new TwoKeyError(
        "license_device_mismatch",
        "This device is not listed on the license. Bind or replace a device.",
      );
    }
  }

  private async bindAndMaybeIssue(
    accessToken: string,
    device: LicenseDeviceIdentity,
    opts: {
      replaceSki?: string;
      friendlyName?: string;
      platform?: "web" | "ios" | "android" | "desktop" | "unknown";
    },
  ): Promise<{ payload: LicensePayload; jwt: string; etag?: string } | null> {
    const result: BindLicenseDeviceResult = await this.api.bindLicenseDevice({
      accessToken,
      publicJwk: device.publicJwk,
      friendlyName: opts.friendlyName ?? device.friendlyName,
      platform: opts.platform ?? "web",
      replaceSki: opts.replaceSki,
      issueLicense: true,
    });
    if (!result.signedToken) return null;
    const payload = await verifyLicenseJwt(result.signedToken, this.config.publicKeyPem);
    return { payload, jwt: result.signedToken };
  }

  private async persistVerified(
    accountKey: string,
    stored: AccountSession,
    payload: LicensePayload,
    jwt: string,
    etag?: string,
    accessToken?: string,
    payingPartyId?: string,
  ): Promise<void> {
    this.payload = payload;
    await this.session.save({
      ...stored,
      accountKey,
      accessToken: accessToken ?? stored.accessToken,
      licenseJwt: jwt,
      licenseEtag: etag ?? stored.licenseEtag,
      payingPartyIdHeader: payingPartyId ?? stored.payingPartyIdHeader,
    });
  }
}

/** Host entry: configure origin, PEM, storage prefix, and optional static catalog. */
export function createBillingClient(
  config: SdkConfig,
  opts?: CreateBillingClientOptions,
): BillingClient {
  return new BillingClient(config, opts);
}
