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

function Resolve-Keytool {
  $cmd = Get-Command keytool -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $candidates = [System.Collections.Generic.List[string]]::new()
  if ($env:JAVA_HOME) {
    $candidates.Add((Join-Path $env:JAVA_HOME "bin\keytool.exe"))
  }
  $candidates.Add("$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe")
  $candidates.Add("${env:ProgramFiles(x86)}\Android\Android Studio\jbr\bin\keytool.exe")
  $candidates.Add("$env:LOCALAPPDATA\Android\Sdk\jbr\bin\keytool.exe")
  foreach ($c in $candidates) {
    if ($c -and (Test-Path $c)) { return $c }
  }

  throw "keytool not found. Install Android Studio (JBR) or add a JDK to PATH / JAVA_HOME."
}

$keytool = Resolve-Keytool
Write-Host "Using keytool: $keytool"

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

& $keytool -genkey -v `
  -keystore $keystore `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias $Alias `
  -storepass $storePlain `
  -keypass $keyPlain `
  -dname $DName

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($props, @"
storePassword=$storePlain
keyPassword=$keyPlain
keyAlias=$Alias
storeFile=upload-keystore.jks
"@, $utf8NoBom)

Write-Host ""
Write-Host "Created:"
Write-Host "  $keystore"
Write-Host "  $props"
Write-Host "BACK THESE UP OFFLINE. Do not commit them."
