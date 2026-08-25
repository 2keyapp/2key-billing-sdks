# two-key CLI

Desktop CLI for 2key Billing — **Windows, macOS, and Linux**.

## Install

Binaries are produced by private **`2key-core-sdk`** Releases (tag `v*`). This repo pins the version in [`../core-binaries.lock.json`](../core-binaries.lock.json).

```bash
# macOS / Linux
./scripts/fetch-binaries.sh
chmod +x bin/two-key
./bin/two-key version

# Windows PowerShell
.\scripts\fetch-binaries.ps1
.\bin\two-key.exe version
```

Override release URL / token for private repos:

| Env | Purpose |
|-----|---------|
| `TWOKEY_CORE_RELEASE_TAG` | Tag to fetch (default from lockfile) |
| `TWOKEY_CORE_REPO` | `owner/repo` (default `2keyapp/2key-core-sdk`) |
| `GITHUB_TOKEN` / `TWOKEY_GH_TOKEN` | Required if the core repo is private |

## Commands

```text
two-key version
two-key normalize-url <url>
two-key check-config
two-key verify-license --pem <public.pem> --jwt <token-or-file>
two-key session-demo
two-key auth-token [token]
two-key sync-license [--etag <etag>] [--party <paying_party_id>]
```

### Environment

| Variable | Used by |
|----------|---------|
| `TWOKEY_API_BASE_URL` | check-config, sync-license, session-demo |
| `TWOKEY_PUBLIC_KEY_PEM` | check-config, sync-license, session-demo |
| `TWOKEY_STORAGE_PREFIX` | session-demo (default `two_key_cli`) |
| `TWOKEY_ACCESS_TOKEN` | auth-token, sync-license |
| `TWOKEY_USE_KEYRING=1` | session-demo uses OS keyring |

## Platform matrix

| OS | Arch | Asset name (from core release) |
|----|------|--------------------------------|
| Linux | x86_64 | `two-key-linux-x86_64` |
| Linux | aarch64 | `two-key-linux-aarch64` |
| macOS | x86_64 | `two-key-macos-x86_64` |
| macOS | aarch64 | `two-key-macos-aarch64` |
| Windows | x86_64 | `two-key-windows-x86_64.exe` |
| Windows | aarch64 | `two-key-windows-aarch64.exe` |

## Development of the CLI

CLI **source** lives in private `2key-core-sdk` (`crates/2key_cli`). Do not reintroduce `two-key-core` source into this public repository.
