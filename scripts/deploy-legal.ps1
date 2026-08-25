# Deploy Play-compliant legal static pages to Azure $web
# Requires: az login
# URL: https://riderlab.rawthrottle.com.mx/legal/...

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot\..

$key = az storage account keys list --account-name riderlabdeck --resource-group rg-nkmoto --query "[0].value" -o tsv
if (-not $key) { throw 'Could not read storage account key' }

$files = @(
  @{ Local = 'docs\legal\delete-account.html'; Blob = 'legal/delete-account.html' },
  @{ Local = 'docs\legal\privacy.html'; Blob = 'legal/privacy.html' },
  @{ Local = 'docs\legal\terms.html'; Blob = 'legal/terms.html' }
)

foreach ($f in $files) {
  if (-not (Test-Path $f.Local)) {
    Write-Warning "Skip missing $($f.Local)"
    continue
  }
  az storage blob upload `
    --account-name riderlabdeck `
    --account-key $key `
    --container-name '$web' `
    --name $f.Blob `
    --file $f.Local `
    --content-type 'text/html' `
    --overwrite true
  Write-Host "Uploaded $($f.Blob)"
}

Write-Host ''
Write-Host 'Paste into Play Console > App content > Data safety > Delete account URL:'
Write-Host '  https://riderlab.rawthrottle.com.mx/legal/delete-account.html'
Write-Host 'Partial data deletion (optional): No'
