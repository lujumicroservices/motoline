$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot 'sas-function'
$zip = Join-Path $PSScriptRoot 'src-only.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
tar.exe -C $root -a -cf $zip host.json package.json src

az functionapp deployment source config-zip `
  --resource-group rg-riderlab `
  --name riderlabimusas `
  --src $zip `
  --build-remote true

Write-Host "Deployed. URL:"
az functionapp show -g rg-riderlab -n riderlabimusas --query defaultHostName -o tsv
