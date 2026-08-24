import type { SdkConfig } from "./config.js";
import { validateConfig } from "./config.js";
import { TwoKeyError } from "./errors.js";

/** Minimal persisted account session (browser). */
export type AccountSession = {
  accountKey: string;
  accessToken?: string;
  licenseJwt?: string;
  licenseEtag?: string;
  payingPartyIdHeader?: string;
};

export type SessionStore = {
  get(key: string): string | null | Promise<string | null>;
  set(key: string, value: string): void | Promise<void>;
  delete(key: string): void | Promise<void>;
};

/** localStorage-backed store (browser). */
export function localStorageSessionStore(): SessionStore {
  return {
    get(key) {
      return globalThis.localStorage?.getItem(key) ?? null;
    },
    set(key, value) {
      globalThis.localStorage?.setItem(key, value);
    },
    delete(key) {
      globalThis.localStorage?.removeItem(key);
    },
  };
}

/** In-memory store (tests / SSR stubs). */
export function memorySessionStore(): SessionStore {
  const map = new Map<string, string>();
  return {
    get: (k) => map.get(k) ?? null,
    set: (k, v) => {
      map.set(k, v);
    },
    delete: (k) => {
      map.delete(k);
    },
  };
}

function sanitize(accountKey: string): string {
  return accountKey.replace(/[^a-zA-Z0-9_-]/g, "_");
}

export class BrowserSessionManager {
  private readonly config: SdkConfig;
  private readonly store: SessionStore;

  constructor(config: SdkConfig, store: SessionStore = memorySessionStore()) {
    this.config = validateConfig(config);
    this.store = store;
  }

  private key(accountKey: string): string {
    return `${this.config.storagePrefix}:session:${sanitize(accountKey)}`;
  }

  async load(accountKey: string): Promise<AccountSession | null> {
    const raw = await this.store.get(this.key(accountKey));
    if (!raw) return null;
    try {
      return JSON.parse(raw) as AccountSession;
    } catch (e) {
      throw new TwoKeyError("unknown", "Corrupt session data", String(e));
    }
  }

  async save(session: AccountSession): Promise<void> {
    await this.store.set(this.key(session.accountKey), JSON.stringify(session));
  }

  async clear(accountKey: string): Promise<void> {
    await this.store.delete(this.key(accountKey));
  }
}
