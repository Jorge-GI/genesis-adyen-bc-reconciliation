# Adyen Event-to-Invoice Reconciliation

Greenfield monorepo for importing Adyen merchant payment events into Business Central Online, applying eligible customer payments to invoices, and confirming completeness with the daily Payment Accounting Report.

## Runtime components

- `azure/src/AdyenBridge.Ingress`: public Azure Function App. App Service Authentication validates Adyen's OAuth token; the function verifies HMAC and merchant/environment, then enqueues the raw notification before returning `202`.
- `azure/src/AdyenBridge.Worker`: private Azure Function App. It archives webhook payloads, normalizes payment events, downloads and parses reports, and calls the versioned Business Central API.
- `business-central`: AL extension. Its APIs only persist inbox/report records; a recurring Job Queue processes them and owns all matching, posting, and application logic.
- `contracts`: JSON schemas and examples that define the boundary between Azure and Business Central.
- `infra`: Bicep deployment for the two Function Apps, Service Bus queues, Blob Storage, identities, and monitoring.

The main happy path is:

`AUTHORISATION success=true` -> ingress -> Service Bus -> worker -> BC inbox -> Job Queue -> exact invoice match -> posted/applied payment -> `SentForSettle` report confirmation.

Business Central object allocation: `72000–72149` for the production app and `72150–72200` for the test app.

See the [architecture](docs/architecture.md), [installation and configuration guide](docs/setup.md),
[testing and validation guide](docs/testing-validation.md), and [operations guide](docs/operations.md).

## Build

Azure requires the .NET 8 SDK:

```powershell
dotnet restore azure/AdyenBridge.sln
dotnet build azure/AdyenBridge.sln --no-restore
dotnet test azure/AdyenBridge.sln --no-build
```

The AL project targets Business Central 28.0/runtime 16.0. Download matching symbols into `business-central/.alpackages` and compile with the AL Language extension or `alc.exe`.

Do not commit `local.settings.json`, credentials, report files, webhook payloads, or generated `.app` packages.
