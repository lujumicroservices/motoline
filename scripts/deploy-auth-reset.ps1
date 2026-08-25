# One-shot deploy for password-reset static page (run from repo root)
# Requires: az login, supabase CLI linked to RiderLab (project eabhnmlfsfibgwkspqwa)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot\..

$keysJson = supabase projects api-keys --project-ref eabhnmlfsfibgwkspqwa -o json
$parsed = $keysJson | ConvertFrom-Json
$anon = ($parsed | Where-Object { $_.name -eq 'anon' }).api_key | Select-Object -First 1
if (-not $anon) { throw 'Could not read anon key from supabase CLI' }

$deploy = Join-Path $env:TEMP 'riderlab-auth-reset-deploy'
New-Item -ItemType Directory -Force -Path $deploy | Out-Null
Copy-Item docs\auth\reset-password.html $deploy\index.html -Force
Set-Content -Encoding utf8 "$deploy\config.js" @"
window.RL_AUTH = {
  supabaseUrl: 'https://eabhnmlfsfibgwkspqwa.supabase.co',
  supabaseAnonKey: '$anon',
};
"@

$key = az storage account keys list --account-name riderlabdeck --resource-group rg-nkmoto --query "[0].value" -o tsv
az storage blob upload --account-name riderlabdeck --account-key $key --container-name '$web' --name 'auth/reset-password/index.html' --file "$deploy\index.html" --content-type 'text/html' --overwrite true
az storage blob upload --account-name riderlabdeck --account-key $key --container-name '$web' --name 'auth/reset-password/config.js' --file "$deploy\config.js" --content-type 'application/javascript' --overwrite true
Remove-Item $deploy -Recurse -Force
Write-Host 'Deployed https://riderlab.rawthrottle.com.mx/auth/reset-password/'
Write-Host ''
Write-Host 'Supabase Dashboard → Authentication → URL Configuration:'
Write-Host '  Site URL: https://riderlab.rawthrottle.com.mx/auth/reset-password/'
Write-Host '  Redirect URLs (keep both):'
Write-Host '    https://riderlab.rawthrottle.com.mx/auth/reset-password/**'
Write-Host '    com.rawthrottle.riderlab://login-callback'
