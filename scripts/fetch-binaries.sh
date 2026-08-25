#!/usr/bin/env bash
# Fetch pinned two-key CLI (+ optional core cdylib) from 2key-core-sdk Releases.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/core-binaries.lock.json"
OUT="$ROOT/bin"
mkdir -p "$OUT"

if [[ -n "${TWOKEY_CORE_DEV_DIR:-}" ]]; then
  echo "TWOKEY_CORE_DEV_DIR set — copying local release build"
  DEV="${TWOKEY_CORE_DEV_DIR%/}"
  if [[ -x "$DEV/target/release/two-key" ]]; then
    cp "$DEV/target/release/two-key" "$OUT/two-key"
    chmod +x "$OUT/two-key"
  elif [[ -x "$DEV/target/debug/two-key" ]]; then
    cp "$DEV/target/debug/two-key" "$OUT/two-key"
    chmod +x "$OUT/two-key"
  else
    echo "No two-key binary under $DEV/target/{release,debug}" >&2
    exit 1
  fi
  # Optional lib for FFI wrappers
  for lib in libtwo_key_core.so libtwo_key_core.dylib; do
    if [[ -f "$DEV/target/release/$lib" ]]; then
      cp "$DEV/target/release/$lib" "$OUT/$lib"
    elif [[ -f "$DEV/target/debug/$lib" ]]; then
      cp "$DEV/target/debug/$lib" "$OUT/$lib"
    fi
  done
  echo "Installed $OUT/two-key (dev)"
  "$OUT/two-key" version || true
  exit 0
fi

TAG="${TWOKEY_CORE_RELEASE_TAG:-}"
REPO="${TWOKEY_CORE_REPO:-}"
if command -v jq >/dev/null 2>&1; then
  TAG="${TAG:-$(jq -r .tag "$LOCK")}"
  REPO="${REPO:-$(jq -r .repo "$LOCK")}"
else
  TAG="${TAG:-v0.1.0}"
  REPO="${REPO:-2keyapp/2key-core-sdk}"
fi

OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS" in
  Linux)  os=linux ;;
  Darwin) os=macos ;;
  *) echo "Unsupported OS: $OS (use fetch-binaries.ps1 on Windows)" >&2; exit 1 ;;
esac
case "$ARCH" in
  x86_64|amd64) arch=x86_64 ;;
  arm64|aarch64) arch=aarch64 ;;
  *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;;
esac

ASSET="two-key-${os}-${arch}"
URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"
TOKEN="${TWOKEY_GH_TOKEN:-${GITHUB_TOKEN:-}}"

echo "Fetching $URL"
AUTH=()
if [[ -n "$TOKEN" ]]; then
  AUTH=(-H "Authorization: Bearer $TOKEN" -H "Accept: application/octet-stream")
fi

TMP="$(mktemp)"
if ! curl -fsSL "${AUTH[@]}" -o "$TMP" "$URL"; then
  echo "Download failed. For a private core repo set GITHUB_TOKEN / TWOKEY_GH_TOKEN," >&2
  echo "or set TWOKEY_CORE_DEV_DIR to a local 2key-core-sdk checkout and rebuild CLI." >&2
  rm -f "$TMP"
  exit 1
fi
mv "$TMP" "$OUT/two-key"
chmod +x "$OUT/two-key"
echo "Installed $OUT/two-key"
"$OUT/two-key" version
