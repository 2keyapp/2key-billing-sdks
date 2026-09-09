import assert from "node:assert/strict";
import { test } from "node:test";
import { LicenseDeviceKeystore, exportDevicePaste } from "./device.ts";
import { memorySessionStore } from "./session.ts";
import { TwoKeyError } from "./errors.ts";

test("LicenseDeviceKeystore persists Ed25519 identity per account", async () => {
  const store = memorySessionStore();
  const ks = new LicenseDeviceKeystore(store, "test");
  const a = await ks.ensureForAccount("acct");
  assert.ok(a.ski.length > 8);
  assert.equal((a.publicJwk as { kty?: string }).kty, "OKP");
  const b = await ks.ensureForAccount("acct");
  assert.equal(b.ski, a.ski);
  const other = await ks.ensureForAccount("other");
  assert.notEqual(other.ski, a.ski);
});

test("exportDevicePaste includes friendlyName and publicJwk only", async () => {
  const store = memorySessionStore();
  const ks = new LicenseDeviceKeystore(store, "test");
  const identity = await ks.ensureForAccount("acct");
  await assert.rejects(
    async () => exportDevicePaste(identity),
    (e: unknown) => e instanceof TwoKeyError && e.code === "config",
  );
  const json = exportDevicePaste({ ...identity, friendlyName: "secMail" });
  const parsed = JSON.parse(json) as {
    friendlyName?: string;
    publicJwk?: unknown;
    privateJwk?: unknown;
    ski?: unknown;
  };
  assert.equal(parsed.friendlyName, "secMail");
  assert.deepEqual(parsed.publicJwk, identity.publicJwk);
  assert.equal(parsed.privateJwk, undefined);
  assert.equal(parsed.ski, undefined);
});
