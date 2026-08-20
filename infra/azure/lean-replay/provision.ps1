# RiderLab IMU replay — dedicated RG (never rg-nkmoto / nkmoto).
# Usage (from repo root, Azure CLI logged in):
#   powershell -File infra/azure/lean-replay/provision.ps1
#
# Set SUPABASE_URL and SUPABASE_ANON_KEY in the environment (or apps/mobile/.env).
# Does not print secrets.

$ErrorActionPreference = 'Stop'

$Rg = 'rg-riderlab'
$Location = 'southcentralus'
$Account = 'riderlabimu'
$Container = 'lean-replay'
$Func = 'riderlabimusas'
$FuncPlanLocation = 'eastus'
$Subscription = az account show --query id -o tsv

function Read-DotEnv([string]$path, [string]$key) {
  if (-not (Test-Path $path)) { return $null }
  foreach ($line in Get-Content $path) {
    if ($line -match "^\s*$key=(.*)$") {
      return $Matches[1].Trim().Trim('"').Trim("'")
    }
  }
  return $null
}

$envFile = Join-Path $PSScriptRoot '..\..\..\apps\mobile\.env'
$SupabaseUrl = $env:SUPABASE_URL
if (-not $SupabaseUrl) { $SupabaseUrl = Read-DotEnv $envFile 'SUPABASE_URL' }
$SupabaseAnon = $env:SUPABASE_ANON_KEY
if (-not $SupabaseAnon) { $SupabaseAnon = Read-DotEnv $envFile 'SUPABASE_ANON_KEY' }
if (-not $SupabaseAnon) { $SupabaseAnon = Read-DotEnv $envFile 'SUPABASE_PUBLISHABLE_KEY' }

if (-not $SupabaseUrl -or -not $SupabaseAnon) {
  throw 'Set SUPABASE_URL and SUPABASE_ANON_KEY (or apps/mobile/.env) before provisioning.'
}

Write-Host "Creating $Rg in $Location (RiderLab only)..."
az group create --name $Rg --location $Location --tags project=riderlab --output none

Write-Host "Creating storage $Account..."
az storage account create `
  --name $Account `
  --resource-group $Rg `
  --location $Location `
  --sku Standard_LRS `
  --kind StorageV2 `
  --access-tier Hot `
  --allow-blob-public-access false `
  --min-tls-version TLS1_2 `
  --https-only true `
  --tags project=riderlab `
  --output none

$key = az storage account keys list --account-name $Account --resource-group $Rg --query '[0].value' -o tsv
az storage container create `
  --name $Container `
  --account-name $Account `
  --account-key $key `
  --public-access off `
  --output none

Write-Host "Creating Function App $Func..."
az functionapp create `
  --name $Func `
  --resource-group $Rg `
  --consumption-plan-location $FuncPlanLocation `
  --runtime node `
  --runtime-version 22 `
  --functions-version 4 `
  --storage-account $Account `
  --os-type Linux `
  --disable-app-insights false `
  --tags project=riderlab `
  --output none

Write-Host "Managed identity + blob roles..."
$principal = az functionapp identity assign --name $Func --resource-group $Rg --query principalId -o tsv
$scope = "/subscriptions/$Subscription/resourceGroups/$Rg/providers/Microsoft.Storage/storageAccounts/$Account"
az role assignment create --assignee $principal --role "Storage Blob Data Contributor" --scope $scope --output none
az role assignment create --assignee $principal --role "Storage Blob Delegator" --scope $scope --output none

az functionapp config appsettings set --name $Func --resource-group $Rg --settings `
  "BLOB_ACCOUNT=$Account" `
  "BLOB_CONTAINER=$Container" `
  "SUPABASE_URL=$SupabaseUrl" `
  "SUPABASE_ANON_KEY=$SupabaseAnon" `
  --output none

Write-Host "Done. Deploy function zip next. Hostname:"
az functionapp show --name $Func --resource-group $Rg --query defaultHostName -o tsv
