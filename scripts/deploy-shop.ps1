# Deploy merch marketplace.
# Visible now: https://riderlab.rawthrottle.com.mx/tienda/
# Azure origin: https://rawthrottlesite.z21.web.core.windows.net/
# rawthrottle.com.mx is still GoDaddy until Cloudflare origin is switched.

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot\..
$Source = Join-Path $PWD 'docs\shop'
$Products = Join-Path $Source 'img\products'

function Publish-Shop {
  param(
    [string]$Account,
    [string]$Rg,
    [string]$Prefix
  )
  $key = az storage account keys list --account-name $Account --resource-group $Rg --query '[0].value' -o tsv
  if (-not $key) { throw "Could not read storage account key for $Account" }
  $pre = if ($Prefix) { "$Prefix/" } else { '' }

  $files = @(
    @{ Local = 'index.html'; Blob = ($pre + 'index.html'); Type = 'text/html; charset=utf-8' },
    @{ Local = 'css\styles.css'; Blob = ($pre + 'css/styles.css'); Type = 'text/css; charset=utf-8' },
    @{ Local = 'js\config.js'; Blob = ($pre + 'js/config.js'); Type = 'application/javascript; charset=utf-8' },
    @{ Local = 'js\main.js'; Blob = ($pre + 'js/main.js'); Type = 'application/javascript; charset=utf-8' },
    @{ Local = 'img\mark.svg'; Blob = ($pre + 'img/mark.svg'); Type = 'image/svg+xml' }
  )
  foreach ($f in $files) {
    az storage blob upload `
      --account-name $Account `
      --account-key $key `
      --container-name '$web' `
      --name $f.Blob `
      --file (Join-Path $Source $f.Local) `
      --content-type $f.Type `
      --overwrite true `
      --output none
    if ($LASTEXITCODE -ne 0) { throw "Upload failed: $Account $($f.Blob)" }
    Write-Host "Uploaded $Account/$($f.Blob)"
  }

  az storage blob upload-batch `
    --account-name $Account `
    --account-key $key `
    --destination '$web' `
    --source $Products `
    --destination-path ($pre + 'img/products') `
    --overwrite true `
    --pattern '*.jpg' `
    --content-type 'image/jpeg' `
    --output none
  if ($LASTEXITCODE -ne 0) { throw "Product image upload failed on $Account" }
  Write-Host "Uploaded $Account/$($pre)img/products/*.jpg"
}

Publish-Shop -Account 'rawthrottlesite' -Rg 'rg-rawthrottle' -Prefix ''
Publish-Shop -Account 'riderlabdeck' -Rg 'rg-nkmoto' -Prefix 'tienda'

Write-Host ''
Write-Host 'See merch now: https://riderlab.rawthrottle.com.mx/tienda/'
Write-Host 'Azure origin:  https://rawthrottlesite.z21.web.core.windows.net/'
