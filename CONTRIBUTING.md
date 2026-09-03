# Contributing

This is a **polyglot SDK monorepo**. Language clients are allowed to differ in runtime. They are not allowed to differ in contract.

## Prerequisites

- Dart / Flutter (stable) for `packages/dart`
- Node.js ≥ 20 and pnpm ≥ 9 for `packages/javascript`

Do not vendor `two-key-core` source. Fetch binaries with `scripts/fetch-binaries.*`. There is no public Rust crate in this repo.

## Make a change

1. **Contract first.** If you touch claim names, error codes, or `/api/v1`, edit `openapi/` and `conformance/` before any language package.
2. **Implement in every shipped language.** Today that is Dart and JavaScript. A fixture-only PR that updates JSON without updating both test suites is incomplete.
3. **Run both suites** even if you only edited one language — `make test`.
4. Conventional commits: `feat(js): …`, `fix(dart): …`, `docs: …`, `chore: …`.

## Language workspaces

### Dart (`packages/dart`)

```bash
cd packages/dart
flutter pub get
flutter test
```

Host git dependency path is `packages/dart`.

### JavaScript (`packages/javascript`)

pnpm workspace. Run commands from `packages/javascript`, not the repo root.

```bash
cd packages/javascript
pnpm install
pnpm run ci
```

JS tests load fixtures from repo-root `conformance/`. Do not copy that tree into `packages/javascript`.

Published entry for hosts: `@2key/browser-sdk`. Internal packages (`@2key/dp-*`, `@2key/catalog-*`) are not host-facing unless a server PEP needs `@2key/dp-authorize`.

## Adding a language

1. Create a sibling under `packages/`: `kotlin/`, `swift/`, `python/`, …
2. Point tests at `conformance/fixtures` and `openapi/2key-billing.yaml`.
3. Add a CI job in `.github/workflows/ci.yml` that **always runs** with the others.
4. Add a row to the README language table.
5. Do not fork OpenAPI or fixtures into the language folder.
6. Do not add a root `pnpm-workspace.yaml` with `packages/*`.

## What not to do

- Do not put Dart inside the JavaScript pnpm workspace, or JS inside the Dart package.
- Do not import Better Auth from a host app.
- Do not wrap the browser SDK in WASM to “share” Rust. JS stays TypeScript.
- Do not skip a language’s tests because the change “cannot affect it.” Conformance changes can.
