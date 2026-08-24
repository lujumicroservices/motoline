# Local Play AAB: optional version bump, then signed playRelease bundle.
# Does not upload by itself — use GitHub Action "play-release" for that,
# or upload the printed .aab in Play Console.
#
# From apps/mobile:
#   powershell -ExecutionPolicy Bypass -File tool/release_play.ps1
#   powershell -ExecutionPolicy Bypass -File tool/release_play.ps1 -BumpPatch

param(
  [switch]$BumpPatch
)

$ErrorActionPreference = "Stop"
$mobileRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $mobileRoot

$pubspec = Join-Path $mobileRoot "pubspec.yaml"
$keystore = Join-Path $mobileRoot "android\upload-keystore.jks"
$props = Join-Path $mobileRoot "android\key.properties"
$envFile = Join-Path $mobileRoot ".env"

if (-not (Test-Path $keystore)) { throw "Missing $keystore" }
if (-not (Test-Path $props)) { throw "Missing $props" }
if (-not (Test-Path $envFile)) { throw "Missing $envFile" }

if ($BumpPatch) {
  $text = Get-Content -Raw $pubspec
  if ($text -notmatch '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$') {
    throw "Could not parse version: in pubspec.yaml"
  }
  $major = [int]$Matches[1]
  $minor = [int]$Matches[2]
  $patch = [int]$Matches[3] + 1
  $code = [int]$Matches[4] + 1
  $next = "$major.$minor.$patch+$code"
  $text = $text -replace '(?m)^version:\s*\d+\.\d+\.\d+\+\d+\s*$', "version: $next"
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [IO.File]::WriteAllText($pubspec, $text.TrimEnd() + "`n", $utf8)
  Write-Host "Bumped pubspec version to $next"
}

$line = (Select-String -Path $pubspec -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
Write-Host "Building Play AAB for $line ..."

flutter gen-l10n
if ($LASTEXITCODE -ne 0) { throw "flutter gen-l10n failed" }
flutter build appbundle --flavor play --release --dart-define=DISTRIBUTION=play
if ($LASTEXITCODE -ne 0) { throw "flutter build appbundle failed" }

$aab = Join-Path $mobileRoot "build\app\outputs\bundle\playRelease\app-play-release.aab"
if (-not (Test-Path $aab)) { throw "AAB not found: $aab" }

$repoRoot = (Resolve-Path (Join-Path $mobileRoot "..\..")).Path
$dist = Join-Path $repoRoot "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$copy = Join-Path $dist "RiderLab-$($line.Replace('+','-')).aab"
Copy-Item -Force $aab $copy

Write-Host ""
Write-Host "AAB ready:"
Write-Host "  $aab"
Write-Host "  $copy"
Write-Host ""
Write-Host "Upload: Play Console → Test and release → Internal testing → Create release"
Write-Host "Or: GitHub → Actions → play-release → Run workflow (after secrets in docs/PLAY_STORE.md §8)"
