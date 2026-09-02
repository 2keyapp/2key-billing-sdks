import { TwoKeyError } from "./errors.js";
import { parseLicenseClaims, type LicensePayload } from "./license.js";

function b64urlToBytes(input: string): Uint8Array<ArrayBuffer> {
  const pad = "=".repeat((4 - (input.length % 4)) % 4);
  const b64 = (input + pad).replace(/-/g, "+").replace(/_/g, "/");
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function pemToSpkiBytes(pem: string): Uint8Array<ArrayBuffer> {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s+/g, "");
  if (!body) {
    throw new TwoKeyError("config", "Invalid publicKeyPem");
  }
  const bin = atob(body);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function importEs256PublicKey(publicKeyPem: string): Promise<CryptoKey> {
  const spki = pemToSpkiBytes(publicKeyPem);
  try {
    return await crypto.subtle.importKey(
      "spki",
      spki,
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["verify"],
    );
  } catch (e) {
    throw new TwoKeyError("config", "Invalid publicKeyPem", String(e));
  }
}

/**
 * Verify ES256 license JWT with Web Crypto, then parse claims.
 * Matches `two-key-core` LicenseVerifier semantics.
 */
export async function verifyLicenseJwt(
  token: string,
  publicKeyPem: string,
  nowUnixSeconds: number = Math.floor(Date.now() / 1000),
): Promise<LicensePayload> {
  const trimmed = token.trim();
  if (!trimmed) {
    throw new TwoKeyError(
      "license_malformed",
      "Invalid format. Please paste the full token from the billing portal.",
    );
  }
  const parts = trimmed.split(".");
  if (parts.length !== 3) {
    throw new TwoKeyError(
      "license_malformed",
      "Invalid format. Please paste the full token from the billing portal.",
    );
  }

  const [headerB64, payloadB64, sigB64] = parts as [string, string, string];

  let header: { alg?: string };
  try {
    header = JSON.parse(new TextDecoder().decode(b64urlToBytes(headerB64))) as {
      alg?: string;
    };
  } catch {
    throw new TwoKeyError(
      "license_malformed",
      "Invalid format. Please paste the full token from the billing portal.",
    );
  }
  if (header.alg !== "ES256") {
    throw new TwoKeyError(
      "license_invalid",
      "Invalid token. It may have been copied incorrectly.",
    );
  }

  const key = await importEs256PublicKey(publicKeyPem);
  const data = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const signature = b64urlToBytes(sigB64);
  let ok = false;
  try {
    ok = await crypto.subtle.verify(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      signature,
      data,
    );
  } catch (e) {
    throw new TwoKeyError(
      "license_invalid",
      "Invalid token. It may have been copied incorrectly.",
      String(e),
    );
  }
  if (!ok) {
    throw new TwoKeyError(
      "license_invalid",
      "Invalid token. It may have been copied incorrectly.",
    );
  }

  let claims: unknown;
  try {
    claims = JSON.parse(new TextDecoder().decode(b64urlToBytes(payloadB64)));
  } catch {
    throw new TwoKeyError(
      "license_malformed",
      "Invalid format. Please paste the full token from the billing portal.",
    );
  }

  const payload = parseLicenseClaims(claims);
  if (nowUnixSeconds > payload.expiresAtUnix) {
    throw new TwoKeyError(
      "license_expired",
      "This token has expired. Please sync or get a new token from the billing portal.",
    );
  }
  return payload;
}
