import { generateEd25519KeyPair } from "@2key/dp-ts";
import { TwoKeyError } from "./errors.js";
import type { SessionStore } from "./session.js";

/** Stored license-device identity for one account/profile. */
export type LicenseDeviceIdentity = {
  publicJwk: Record<string, unknown>;
  ski: string;
  privateJwk?: Record<string, unknown>;
  friendlyName?: string;
};

function sanitize(accountKey: string): string {
  return accountKey.replace(/[^a-zA-Z0-9_-]/g, "_");
}

/**
 * Generates and persists a license-device Ed25519 key (RFC 7638 SKI).
 * Parity with Dart `LicenseDeviceKeystore`.
 */
export class LicenseDeviceKeystore {
  constructor(
    private readonly store: SessionStore,
    private readonly storagePrefix: string,
  ) {}

  private key(accountKey: string): string {
    return `${this.storagePrefix}:license_device_v1:${sanitize(accountKey)}`;
  }

  async ensureForAccount(accountKey: string): Promise<LicenseDeviceIdentity> {
    const existing = await this.loadForAccount(accountKey);
    if (existing) return existing;
    const created = await this.generate();
    await this.persistForAccount(accountKey, created);
    return created;
  }

  async loadForAccount(accountKey: string): Promise<LicenseDeviceIdentity | null> {
    const raw = await this.store.get(this.key(accountKey));
    if (!raw?.trim()) return null;
    try {
      const parsed = JSON.parse(raw) as LicenseDeviceIdentity;
      if (!parsed.ski || !parsed.publicJwk) return null;
      return parsed;
    } catch {
      return null;
    }
  }

  async persistForAccount(
    accountKey: string,
    identity: LicenseDeviceIdentity,
  ): Promise<void> {
    await this.store.set(this.key(accountKey), JSON.stringify(identity));
  }

  private async generate(): Promise<LicenseDeviceIdentity> {
    const kp = await generateEd25519KeyPair();
    return {
      publicJwk: kp.publicJwk as Record<string, unknown>,
      ski: kp.ski,
      privateJwk: kp.privateJwk,
    };
  }
}

/** Persist a user-chosen label on a generated identity. */
export function withFriendlyName(
  identity: LicenseDeviceIdentity,
  friendlyName?: string,
): LicenseDeviceIdentity {
  const name = friendlyName?.trim();
  if (!name) return identity;
  return { ...identity, friendlyName: name };
}

export function assertDeviceIdentity(identity: LicenseDeviceIdentity): void {
  if (!identity.ski?.trim() || !identity.publicJwk) {
    throw new TwoKeyError("config", "License device identity is incomplete.");
  }
}
