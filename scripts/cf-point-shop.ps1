# Point rawthrottle.com.mx + www at the Azure merch shop.
# Reads token from gitignored .env.cloudflare. Does not print the token.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot\..

$envPath = Join-Path $PWD '.env.cloudflare'
$vars = @{}
Get-Content $envPath | ForEach-Object {
  if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
  $k, $v = $_.Split('=', 2)
  $vars[$k.Trim()] = $v.Trim()
}
$token = $vars['CLOUDFLARE_API_TOKEN']
$zoneName = $vars['CLOUDFLARE_ZONE']
if (-not $token) { throw 'CLOUDFLARE_API_TOKEN missing' }
if (-not $zoneName) { throw 'CLOUDFLARE_ZONE missing' }

$headers = @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' }
$zoneId = (Invoke-RestMethod -Method GET -Uri "https://api.cloudflare.com/client/v4/zones?name=$zoneName" -Headers $headers).result[0].id
$origin = 'rawthrottlesite.z21.web.core.windows.net'
$asverifyTarget = 'asverify.rawthrottlesite.blob.core.windows.net'

function Get-CfRecords {
  return (Invoke-RestMethod -Method GET -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?per_page=100" -Headers $headers).result
}
function Find-Rec($list, $type, $name) {
  return @($list | Where-Object { $_.type -eq $type -and $_.name -eq $name })[0]
}

$recs = Get-CfRecords

$as = Find-Rec $recs 'CNAME' "asverify.$zoneName"
if (-not $as) {
  $body = @{ type = 'CNAME'; name = 'asverify'; content = $asverifyTarget; proxied = $false; ttl = 300 } | ConvertTo-Json
  $created = Invoke-RestMethod -Method POST -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records" -Headers $headers -Body $body
  if (-not $created.success) { throw ($created | ConvertTo-Json -Depth 8) }
  Write-Host 'created asverify'
} else {
  Write-Host "asverify ok $($as.content)"
}

foreach ($a in @($recs | Where-Object { $_.type -eq 'A' -and $_.name -eq $zoneName })) {
  Invoke-RestMethod -Method DELETE -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$($a.id)" -Headers $headers | Out-Null
  Write-Host "deleted A $($a.content)"
}

$recs = Get-CfRecords
$bodyApex = @{ type = 'CNAME'; name = '@'; content = $origin; proxied = $true; ttl = 1 } | ConvertTo-Json
$apex = Find-Rec $recs 'CNAME' $zoneName
if ($apex) {
  $upd = Invoke-RestMethod -Method PUT -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$($apex.id)" -Headers $headers -Body $bodyApex
  if (-not $upd.success) { throw ($upd | ConvertTo-Json -Depth 8) }
  Write-Host 'updated apex CNAME'
} else {
  $created = Invoke-RestMethod -Method POST -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records" -Headers $headers -Body $bodyApex
  if (-not $created.success) { throw ($created | ConvertTo-Json -Depth 8) }
  Write-Host 'created apex CNAME'
}

$recs = Get-CfRecords
$bodyWww = @{ type = 'CNAME'; name = 'www'; content = $origin; proxied = $true; ttl = 1 } | ConvertTo-Json
$www = Find-Rec $recs 'CNAME' "www.$zoneName"
if ($www) {
  $upd = Invoke-RestMethod -Method PUT -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$($www.id)" -Headers $headers -Body $bodyWww
  if (-not $upd.success) { throw ($upd | ConvertTo-Json -Depth 8) }
  Write-Host 'updated www CNAME'
} else {
  $created = Invoke-RestMethod -Method POST -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records" -Headers $headers -Body $bodyWww
  if (-not $created.success) { throw ($created | ConvertTo-Json -Depth 8) }
  Write-Host 'created www CNAME'
}

Write-Host 'binding Azure custom domain'
az storage account update --name rawthrottlesite --resource-group rg-rawthrottle --custom-domain $zoneName --use-subdomain true --query customDomain -o json
if ($LASTEXITCODE -ne 0) {
  az storage account update --name rawthrottlesite --resource-group rg-rawthrottle --custom-domain $zoneName --query customDomain -o json
}

Write-Host '---'
foreach ($r in (Get-CfRecords)) {
  if ($r.name -eq $zoneName -or $r.name -eq "www.$zoneName" -or $r.name -eq "asverify.$zoneName") {
    Write-Host ("{0,-6} {1,-42} {2} proxied={3}" -f $r.type, $r.name, $r.content, $r.proxied)
  }
}
