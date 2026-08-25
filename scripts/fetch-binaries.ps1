# Fetch pinned two-key CLI from 2key-core-sdk Releases (Windows).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$LockPath = Join-Path $Root "core-binaries.lock.json"
$Out = Join-Path $Root "bin"
New-Item -ItemType Directory -Force -Path $Out | Out-Null

if ($env:TWOKEY_CORE_DEV_DIR) {
  Write-Host "TWOKEY_CORE_DEV_DIR set - copying local build"
  $dev = $env:TWOKEY_CORE_DEV_DIR.TrimEnd('\', '/')
  $candidates = @(
    (Join-Path $dev "target\release\two-key.exe"),
    (Join-Path $dev "target\debug\two-key.exe")
  )
  $src = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $src) {
    throw "No two-key.exe under $dev\target\release or target\debug"
  }
  Copy-Item $src (Join-Path $Out "two-key.exe") -Force
  $dllCandidates = @(
    (Join-Path $dev "target\release\two_key_core.dll"),
    (Join-Path $dev "target\debug\two_key_core.dll")
  )
  $dll = $dllCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($dll) {
    Copy-Item $dll (Join-Path $Out "two_key_core.dll") -Force
  }
  $exe = Join-Path $Out "two-key.exe"
  Write-Host "Installed $exe (dev)"
  & $exe version
  exit 0
}

$lock = Get-Content $LockPath -Raw | ConvertFrom-Json
$tag = if ($env:TWOKEY_CORE_RELEASE_TAG) { $env:TWOKEY_CORE_RELEASE_TAG } else { $lock.tag }
$repo = if ($env:TWOKEY_CORE_REPO) { $env:TWOKEY_CORE_REPO } else { $lock.repo }

$arch = switch ($env:PROCESSOR_ARCHITECTURE) {
  "AMD64" { "x86_64" }
  "ARM64" { "aarch64" }
  default { throw "Unsupported arch: $($env:PROCESSOR_ARCHITECTURE)" }
}
$asset = "two-key-windows-${arch}.exe"
$url = "https://github.com/$repo/releases/download/$tag/$asset"
$dest = Join-Path $Out "two-key.exe"

Write-Host "Fetching $url"
$headers = @{
  "Accept" = "application/octet-stream"
}
$token = $null
if ($env:TWOKEY_GH_TOKEN) { $token = $env:TWOKEY_GH_TOKEN }
elseif ($env:GITHUB_TOKEN) { $token = $env:GITHUB_TOKEN }
if ($token) { $headers["Authorization"] = "Bearer $token" }

try {
  Invoke-WebRequest -Uri $url -Headers $headers -OutFile $dest -UseBasicParsing
} catch {
  Write-Error "Download failed. For a private core repo set GITHUB_TOKEN / TWOKEY_GH_TOKEN, or set TWOKEY_CORE_DEV_DIR to a local 2key-core-sdk checkout. $_"
  exit 1
}

Write-Host "Installed $dest"
& $dest version
