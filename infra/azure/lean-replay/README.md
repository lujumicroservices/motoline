# RiderLab IMU replay (Azure Blob)

Dedicated Azure resources for lean IMU dumps. **Do not** put these in `rg-nkmoto` (nkmoto is a separate project).

| Resource | Name |
| --- | --- |
| Resource group | `rg-riderlab` (never `rg-nkmoto`) |
| Storage account | `riderlabimu` (southcentralus) |
| Container | `lean-replay` (private) |
| Function | `riderlabimusas` (eastus consumption) |

The phone never gets the storage account key. It asks the Function for a 15-minute write SAS after validating the Supabase JWT.

```powershell
powershell -File infra/azure/lean-replay/provision.ps1
powershell -File infra/azure/lean-replay/deploy.ps1
```

Then set `AZURE_LEAN_SAS_URL` in `apps/mobile/.env`:

```
AZURE_LEAN_SAS_URL=https://riderlabimusas.azurewebsites.net/api/lean-replay-sas
```
