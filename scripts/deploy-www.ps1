# Deploy the RiderLab public landing to Azure $web (riderlabdeck).
# Requires: az login, Python 3 with qrcode[pil]
#
# URL: https://riderlab.rawthrottle.com.mx/
# Partner decks remain at /short.es.html etc. Hub moves to /partners/
# Does not overwrite /watch, /legal, /auth, or partner-deck /img.
#
# iOS store URL: set iosUrl in docs/www/store.json, then re-run this script.

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot\..

$Rg = 'rg-nkmoto'
$Account = 'riderlabdeck'
$Source = Join-Path $PWD 'docs\www'
$Stage = Join-Path $Source '_dist'
$StorePath = Join-Path $Source 'store.json'

if (-not (Test-Path $StorePath)) { throw "Missing $StorePath" }
$store = Get-Content $StorePath -Raw | ConvertFrom-Json

$key = az storage account keys list --account-name $Account --resource-group $Rg --query '[0].value' -o tsv
if (-not $key) { throw 'Could not read storage account key' }

if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $Stage 'site') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Stage 'go\android') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Stage 'go\ios') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Stage 'go\apk') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Stage 'partners') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Stage 'simm') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Stage 'app') | Out-Null

Copy-Item (Join-Path $Source 'index.html') (Join-Path $Stage 'index.html')
Copy-Item (Join-Path $Source '404.html') (Join-Path $Stage '404.html')
Copy-Item (Join-Path $Source 'store.json') (Join-Path $Stage 'store.json')
Copy-Item (Join-Path $Source 'go\android\index.html') (Join-Path $Stage 'go\android\index.html')
Copy-Item (Join-Path $Source 'go\apk\index.html') (Join-Path $Stage 'go\apk\index.html')
Copy-Item (Join-Path $Source 'simm\index.html') (Join-Path $Stage 'simm\index.html')

$envFile = Join-Path $PWD 'apps\mobile\.env'
$anon = ''
$sbUrl = 'https://eabhnmlfsfibgwkspqwa.supabase.co'
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*SUPABASE_URL=(.+)$') { $sbUrl = $Matches[1].Trim().Trim('"') }
    if ($_ -match '^\s*SUPABASE_ANON_KEY=(.+)$') { $anon = $Matches[1].Trim().Trim('"') }
    if ($_ -match '^\s*SUPABASE_PUBLISHABLE_KEY=(.+)$' -and -not $anon) {
      $anon = $Matches[1].Trim().Trim('"')
    }
  }
}
if (-not $anon) {
  Write-Warning 'No SUPABASE_ANON_KEY in apps/mobile/.env — /simm form will ask staff to take details.'
}
$simmCfg = @"
window.RL_SIMM = {
  supabaseUrl: "$sbUrl",
  supabaseAnonKey: "$anon",
};
"@
Set-Content -Path (Join-Path $Stage 'simm\config.js') -Value $simmCfg -Encoding utf8

$iosUrl = [string]$store.iosUrl
if ($iosUrl) {
  $iosHtml = @"
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>RiderLab — App Store</title>
  <meta http-equiv="refresh" content="0;url=$iosUrl" />
  <link rel="canonical" href="$iosUrl" />
  <script>location.replace("$iosUrl");</script>
  <style>
    :root { --bg:#0e1013; --mist:#f1f5f8; --steel:#9ba4ae; --line:#00d4aa; }
    body { margin:0; min-height:100vh; display:grid; place-items:center; background:var(--bg); color:var(--mist); font-family:system-ui,sans-serif; text-align:center; padding:32px; }
    a { color:var(--line); } p { color:var(--steel); }
  </style>
</head>
<body>
  <main>
    <p>Abriendo App Store…</p>
    <p><a href="$iosUrl">Descargar RiderLab en iPhone</a></p>
  </main>
</body>
</html>
"@
  Set-Content -Path (Join-Path $Stage 'go\ios\index.html') -Value $iosHtml -Encoding utf8
} else {
  Copy-Item (Join-Path $Source 'go\ios\index.html') (Join-Path $Stage 'go\ios\index.html')
}

$hub = Get-Content 'docs\partner-deck\index.html' -Raw
$hub = $hub.Replace('href="deck.css"', 'href="/deck.css"')
$hub = $hub.Replace('href="short.es.html"', 'href="/short.es.html"')
$hub = $hub.Replace('href="full.es.html"', 'href="/full.es.html"')
$hub = $hub.Replace('href="short.html"', 'href="/short.html"')
$hub = $hub.Replace('href="full.html"', 'href="/full.html"')
Set-Content -Path (Join-Path $Stage 'partners\index.html') -Value $hub -Encoding utf8

Copy-Item 'docs\store\play\icon-512.png' (Join-Path $Stage 'site\icon-512.png')
Copy-Item 'docs\store\signage\riderlab-sign-wordmark.png' (Join-Path $Stage 'site\wordmark.png')
Copy-Item 'docs\store\play\feature-graphic-1024x500.png' (Join-Path $Stage 'site\hero.png')
Copy-Item 'docs\store\play\phone-01-home.png' (Join-Path $Stage 'site\phone-01-home.png')
Copy-Item 'docs\store\play\phone-02-live-map.png' (Join-Path $Stage 'site\phone-02-live-map.png')
Copy-Item 'docs\store\play\phone-03-ride-lab.png' (Join-Path $Stage 'site\phone-03-ride-lab.png')
Copy-Item 'docs\store\play\phone-04-lean-gauge.png' (Join-Path $Stage 'site\phone-04-lean-gauge.png')
Copy-Item 'docs\store\play\phone-05-full-map.png' (Join-Path $Stage 'site\phone-05-full-map.png')
Copy-Item (Join-Path $Source 'site\howto-1-tester.jpg') (Join-Path $Stage 'site\howto-1-tester.jpg')
Copy-Item (Join-Path $Source 'site\howto-2-joined.jpg') (Join-Path $Stage 'site\howto-2-joined.jpg')
Copy-Item (Join-Path $Source 'site\howto-3-install.jpg') (Join-Path $Stage 'site\howto-3-install.jpg')

$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
python -c "import qrcode" 2>$null
$qrMissing = $LASTEXITCODE -ne 0
$ErrorActionPreference = $prevEap
if ($qrMissing) {
  python -m pip install --quiet 'qrcode[pil]'
}
$env:RL_QR_OUT = Join-Path $Stage 'site'
python (Join-Path $Source 'gen_qr.py')
if ($LASTEXITCODE -ne 0) { throw 'QR generation failed' }

$apkSrcs = @(
  (Join-Path $PWD 'apps\mobile\build\app\outputs\flutter-apk\app-sideload-release.apk'),
  (Join-Path $PWD 'dist\RiderLab-sideload.apk')
)
$apkSrc = $apkSrcs | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $apkSrc) {
  throw 'Missing sideload APK. Build: flutter build apk --flavor sideload --release --dart-define=DISTRIBUTION=sideload'
}
Copy-Item -Force $apkSrc (Join-Path $Stage 'app\riderlab.apk')
Write-Host "APK $($apkSrc) -> app/riderlab.apk"

$uploads = @(
  @{ File = 'index.html'; Blob = 'index.html'; Type = 'text/html; charset=utf-8' },
  @{ File = '404.html'; Blob = '404.html'; Type = 'text/html; charset=utf-8' },
  @{ File = 'store.json'; Blob = 'store.json'; Type = 'application/json' },
  @{ File = 'partners\index.html'; Blob = 'partners/index.html'; Type = 'text/html; charset=utf-8' },
  @{ File = 'go\android\index.html'; Blob = 'go/android/index.html'; Type = 'text/html; charset=utf-8' },
  @{ File = 'go\ios\index.html'; Blob = 'go/ios/index.html'; Type = 'text/html; charset=utf-8' },
  @{ File = 'go\apk\index.html'; Blob = 'go/apk/index.html'; Type = 'text/html; charset=utf-8' },
  @{ File = 'simm\index.html'; Blob = 'simm/index.html'; Type = 'text/html; charset=utf-8' },
  @{ File = 'simm\config.js'; Blob = 'simm/config.js'; Type = 'application/javascript; charset=utf-8' },
  @{ File = 'site\icon-512.png'; Blob = 'site/icon-512.png'; Type = 'image/png' },
  @{ File = 'site\wordmark.png'; Blob = 'site/wordmark.png'; Type = 'image/png' },
  @{ File = 'site\hero.png'; Blob = 'site/hero.png'; Type = 'image/png' },
  @{ File = 'site\phone-01-home.png'; Blob = 'site/phone-01-home.png'; Type = 'image/png' },
  @{ File = 'site\phone-02-live-map.png'; Blob = 'site/phone-02-live-map.png'; Type = 'image/png' },
  @{ File = 'site\phone-03-ride-lab.png'; Blob = 'site/phone-03-ride-lab.png'; Type = 'image/png' },
  @{ File = 'site\phone-04-lean-gauge.png'; Blob = 'site/phone-04-lean-gauge.png'; Type = 'image/png' },
  @{ File = 'site\phone-05-full-map.png'; Blob = 'site/phone-05-full-map.png'; Type = 'image/png' },
  @{ File = 'site\qr-android.png'; Blob = 'site/qr-android.png'; Type = 'image/png' },
  @{ File = 'site\qr-ios.png'; Blob = 'site/qr-ios.png'; Type = 'image/png' },
  @{ File = 'site\qr-apk.png'; Blob = 'site/qr-apk.png'; Type = 'image/png' },
  @{ File = 'site\howto-1-tester.jpg'; Blob = 'site/howto-1-tester.jpg'; Type = 'image/jpeg' },
  @{ File = 'site\howto-2-joined.jpg'; Blob = 'site/howto-2-joined.jpg'; Type = 'image/jpeg' },
  @{ File = 'site\howto-3-install.jpg'; Blob = 'site/howto-3-install.jpg'; Type = 'image/jpeg' },
  @{ File = 'site\qr-simm.png'; Blob = 'site/qr-simm.png'; Type = 'image/png' },
  @{ File = 'site\promo-stand.jpg'; Blob = 'site/promo-stand.jpg'; Type = 'image/jpeg' },
  @{ File = 'site\promo-stand.mp4'; Blob = 'site/promo-stand.mp4'; Type = 'video/mp4' },
  @{ File = 'app\riderlab.apk'; Blob = 'app/riderlab.apk'; Type = 'application/vnd.android.package-archive'; Disposition = 'attachment; filename="RiderLab.apk"' }
)

foreach ($f in $uploads) {
  $local = Join-Path $Stage $f.File
  $args = @(
    'storage', 'blob', 'upload',
    '--account-name', $Account,
    '--account-key', $key,
    '--container-name', '$web',
    '--name', $f.Blob,
    '--file', $local,
    '--content-type', $f.Type,
    '--overwrite', 'true',
    '--output', 'none'
  )
  if ($f.Disposition) {
    $args += @('--content-disposition', $f.Disposition)
  }
  az @args
  if ($LASTEXITCODE -ne 0) { throw "Upload failed: $($f.Blob)" }
  Write-Host "Uploaded $($f.Blob)"
}

Write-Host ''
Write-Host 'Live:     https://riderlab.rawthrottle.com.mx/'
Write-Host 'APK:      https://riderlab.rawthrottle.com.mx/app/riderlab.apk'
Write-Host 'APK page: https://riderlab.rawthrottle.com.mx/go/apk'
Write-Host 'Partners: https://riderlab.rawthrottle.com.mx/partners/'
Write-Host ''
Write-Host 'QR codes encode:'
Write-Host "  $($store.publicOrigin)/go/apk"
Write-Host "  $($store.publicOrigin)/go/android"
Write-Host "  $($store.publicOrigin)/go/ios"
Write-Host "  $($store.publicOrigin)/simm"
Write-Host 'SIMM:     https://riderlab.rawthrottle.com.mx/simm'
