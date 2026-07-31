# Creates android/upload-keystore.jks + android/key.properties (gitignored).
# Run once from apps/mobile, then BACK UP the .jks + passwords offline forever.
# Losing this keystore means you cannot update the Play Store listing.

param(
  [string]$Alias = "upload",
  [string]$DName = "CN=RiderLab, OU=RawThrottle, O=RawThrottle, C=MX"
)

$ErrorActionPreference = "Stop"
$androidDir = (Resolve-Path (Join-Path $PSScriptRoot "..\android")).Path
$keystore = Join-Path $androidDir "upload-keystore.jks"
$props = Join-Path $androidDir "key.properties"

if (Test-Path $keystore) {
  Write-Host "Keystore already exists: $keystore"
  Write-Host "Aborting so we do not overwrite your upload key."
  exit 1
}

$storePass = Read-Host "New keystore password (store)" -AsSecureString
$keyPass = Read-Host "Key password (can match store)" -AsSecureString
$storePlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePass)
)
$keyPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPass)
)

keytool -genkey -v `
  -keystore $keystore `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias $Alias `
  -storepass $storePlain `
  -keypass $keyPlain `
  -dname $DName

@"
storePassword=$storePlain
keyPassword=$keyPlain
keyAlias=$Alias
storeFile=upload-keystore.jks
"@ | Set-Content -Path $props -Encoding UTF8

Write-Host ""
Write-Host "Created:"
Write-Host "  $keystore"
Write-Host "  $props"
Write-Host "BACK THESE UP OFFLINE. Do not commit them."
