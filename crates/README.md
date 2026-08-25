# Crates removed from the public tree (Binary Private Core)

Native source for `two-key-core` and `two-key-cli` lives in the **private** repo:

**https://github.com/2keyapp/2key-core-sdk** (`crates/2key_core`, `crates/2key_cli`)

Public consumers:

1. Run `scripts/fetch-binaries.sh` or `scripts/fetch-binaries.ps1` to install the `two-key` CLI.
2. Language wrappers load `libtwo_key_core` / `two_key_core.dll` from the same release (see `core-binaries.lock.json`).
3. Internal developers set `TWOKEY_CORE_DEV_DIR` to a local `2key-core-sdk` checkout after `cargo build -p two-key-cli --release`.
