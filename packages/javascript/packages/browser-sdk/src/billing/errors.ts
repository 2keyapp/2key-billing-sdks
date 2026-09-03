/** Shared error codes — keep in sync with docs/error-codes.md and Rust ErrorCode. */
export type ErrorCode =
  | "config"
  | "network"
  | "unauthorized"
  | "offline"
  | "license_invalid"
  | "license_expired"
  | "license_malformed"
  | "license_device_mismatch"
  | "not_modified"
  | "invalid_response"
  | "conflict"
  | "unknown";

export class TwoKeyError extends Error {
  readonly code: ErrorCode;
  readonly detail?: string;

  constructor(code: ErrorCode, message: string, detail?: string) {
    super(message);
    this.name = "TwoKeyError";
    this.code = code;
    this.detail = detail;
  }
}
