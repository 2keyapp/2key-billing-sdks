# Language packages

Using-party SDKs live here, one folder per language.

| Path | Package | Tooling |
|------|---------|---------|
| [`dart/`](dart/) | `two_key_dart_sdk` | Flutter / pub |
| [`javascript/`](javascript/) | `@2key/browser-sdk` + `@2key/dp-*` | pnpm (workspace file is **inside** this folder) |

pnpm must not use a root `packages/*` glob — that would treat Dart as an npm package. Run JS commands from `packages/javascript`.

Add `kotlin/`, `swift/`, `python/` as siblings when those SDKs exist. Native Rust core stays in private `2key-core-sdk`, not here.
