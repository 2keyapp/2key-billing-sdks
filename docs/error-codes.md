# Shared error codes

Stable snake_case strings returned by `two-key-core` (`ErrorCode::as_str`) and mirrored by `@2key/ts-sdk`.

| Code | Meaning |
|------|---------|
| `config` | Missing/invalid SDK configuration |
| `network` | Transport failure |
| `unauthorized` | Missing/invalid auth (HTTP 401/403) |
| `offline` | Offline policy path |
| `license_invalid` | Bad ES256 signature / alg |
| `license_expired` | JWT `exp` passed |
| `license_malformed` | Missing/invalid claims or JWT shape |
| `not_modified` | License HTTP 304 / ETag hit without usable cache |
| `invalid_response` | Unexpected JSON from server |
| `unknown` | Unclassified |

Do not invent parallel codes in wrappers; extend this table in a PR that updates Rust + TS + docs together.
