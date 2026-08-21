# RiderLab IMU replay (Azure Blob)

Dedicated Azure resources for lean IMU dumps. **Do not** put these in `rg-nkmoto` (nkmoto is a separate project).

| Resource | Name |
| --- | --- |
| Resource group | `rg-riderlab` (never `rg-nkmoto`) |
| Storage account | `riderlabimu` (southcentralus) |
| Container | `lean-replay` (private) |
| Function | `riderlabimusas` (eastus consumption) |

The phone never gets the storage account key. It asks the Function for a 15-minute write SAS after validating the Supabase JWT.

Overwrite protection on `riderlabimu`:

| Setting | Value |
| --- | --- |
| Blob **versioning** | On — a PUT to the same `{user}/{ride}.sqlite.gz` keeps the previous file as a version |
| Blob **soft delete** | 30 days — a delete can be undeleted |
| Container **soft delete** | 30 days |

Versions only exist from the moment versioning was turned on; files overwritten before that cannot be recovered.

Recover a previous version (Portal): Storage account `riderlabimu` → container `lean-replay` → blob → **Versions** → select version → **Make current**.

CLI:

```powershell
az storage blob list --account-name riderlabimu --container-name lean-replay --include v --auth-mode login
az storage blob copy start --account-name riderlabimu --destination-container lean-replay --destination-blob "<path>" --source-uri "https://riderlabimu.blob.core.windows.net/lean-replay/<path>?versionId=<id>" --auth-mode login
```

```powershell
powershell -File infra/azure/lean-replay/provision.ps1
powershell -File infra/azure/lean-replay/deploy.ps1
```

Then set `AZURE_LEAN_SAS_URL` in `apps/mobile/.env`:

```
AZURE_LEAN_SAS_URL=https://riderlabimusas.azurewebsites.net/api/lean-replay-sas
```
