# Shared FFI notes (public)

Language wrappers load **prebuilt** `libtwo_key_core` / `two_key_core.dll` from private **`2key-core-sdk`** Releases.

```bash
./scripts/fetch-binaries.sh
# or TWOKEY_CORE_DEV_DIR=/path/to/2key-core-sdk ./scripts/fetch-binaries.sh
export TWOKEY_CORE_LIB="$PWD/bin/libtwo_key_core.so"   # Linux example
```

Rust **source** is not in this repository. See `crates/README.md` and `docs/cli.md`.

## UniFFI (Kotlin / Swift)

See [uniffi/README.md](uniffi/README.md) — scaffold only until private core adds IDL.
