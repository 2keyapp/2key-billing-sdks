import assert from "node:assert/strict";
import { test } from "node:test";
import { LicenseDeviceKeystore } from "./device.ts";
import { memorySessionStore } from "./session.ts";

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
