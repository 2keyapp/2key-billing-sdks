# Native core is private

`two-key-core` and `two-key` CLI **source** live in [`2key-core-sdk`](https://github.com/2keyapp/2key-core-sdk). This public repo does not ship Rust crates.

Public consumers:

1. Run `scripts/fetch-binaries.sh` or `scripts/fetch-binaries.ps1` to install the `two-key` CLI.
2. Language wrappers load `libtwo_key_core` / `two_key_core.dll` from the same release (`core-binaries.lock.json`).
3. Internal developers set `TWOKEY_CORE_DEV_DIR` to a local `2key-core-sdk` checkout after `cargo build -p two-key-cli --release`.

Machine AuthN / agent-token HTTP belongs in `packages/dart` and `packages/javascript` (`@2key/dp-ts`), not a public `billing_http` crate.
