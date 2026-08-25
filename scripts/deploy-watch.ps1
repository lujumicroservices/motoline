# One-shot deploy for Family Watch static page (run from repo root)
# Requires: az login, supabase CLI linked to RiderLab (project eabhnmlfsfibgwkspqwa)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot\..

$keysJson = supabase projects api-keys --project-ref eabhnmlfsfibgwkspqwa -o json
$parsed = $keysJson | ConvertFrom-Json
$anon = ($parsed | Where-Object { $_.name -eq 'anon' }).api_key | Select-Object -First 1
if (-not $anon) { throw 'Could not read anon key from supabase CLI' }

$deploy = Join-Path $env:TEMP 'riderlab-watch-deploy'
New-Item -ItemType Directory -Force -Path $deploy | Out-Null
Copy-Item docs\watch\index.html $deploy\index.html -Force
Set-Content -Encoding utf8 "$deploy\config.js" @"
window.RL_WATCH = {
  supabaseUrl: 'https://eabhnmlfsfibgwkspqwa.supabase.co',
  supabaseAnonKey: '$anon',
};
"@

$key = az storage account keys list --account-name riderlabdeck --resource-group rg-nkmoto --query "[0].value" -o tsv
az storage blob upload --account-name riderlabdeck --account-key $key --container-name '$web' --name 'watch/index.html' --file "$deploy\index.html" --content-type 'text/html' --overwrite true
az storage blob upload --account-name riderlabdeck --account-key $key --container-name '$web' --name 'watch/config.js' --file "$deploy\config.js" --content-type 'application/javascript' --overwrite true
Remove-Item $deploy -Recurse -Force
Write-Host 'Deployed https://riderlab.rawthrottle.com.mx/watch/'
