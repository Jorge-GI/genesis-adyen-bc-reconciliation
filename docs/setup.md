# Installation and configuration guide

This guide installs the complete Adyen-to-Business Central reconciliation solution in a test environment and then promotes the same configuration pattern to production. Complete the [testing and validation guide](testing-validation.md) in an Adyen test merchant and a Business Central sandbox before enabling automatic posting or deploying to production.

The solution is designed for Business Central Online. The extension targets Business Central application/platform `28.0` and AL runtime `16.0`; the Azure Functions target .NET 8.

## 1. Installation responsibilities

Assign named owners before starting. One person may hold more than one role, but each approval must remain attributable.

| Owner | Required access | Responsibility |
|---|---|---|
| Entra administrator | Create app registrations, expose an API, grant application consent | Adyen-to-ingress and worker-to-BC identities |
| Azure administrator | Resource group deployment and role-assignment rights | Infrastructure, Key Vault, Function deployment, monitoring |
| Adyen administrator | Merchant admin, webhook, report, and API-credential rights | Capture policy, webhook, HMAC, lifecycle events, report schedule |
| Business Central administrator | Admin Center app management or `EXTEN. MGT. - ADMIN` | Install the extension and register the service application |
| Business Central finance owner | Journal setup and payment-posting rights | Clearing account, journal batches, method approval, finance sign-off |
| Test lead | Sandbox and read access to Azure evidence | Execute and approve the validation package |

Use licensed or delegated Business Central users for extension management. Microsoft 365 administrator status by itself does not grant permission to install a per-tenant extension.

## 2. Prerequisites

Install these tools on the build/deployment workstation:

- .NET 8 SDK matching `global.json`.
- Azure CLI with Bicep support.
- Azure Functions Core Tools v4.
- Visual Studio Code with the Microsoft AL Language extension.
- Access to a Business Central sandbox compatible with application/platform 28.0.
- Access to separate Azure resource groups, Adyen merchant accounts, Entra applications, HMAC keys, and Business Central environments for test and production.

Confirm the tools before building:

```powershell
dotnet --info
az version
az bicep version
func --version
```

Do not put client secrets, HMAC keys, report passwords, raw webhooks, or downloaded reports in the repository, parameter files, screenshots, or test evidence.

## 3. Deployment worksheet

Record identifiers in an approved deployment record. Do not record secret values.

| Value | Test | Production |
|---|---|---|
| Azure subscription and resource group |  |  |
| Azure location and deployment prefix |  |  |
| Entra tenant ID |  |  |
| Ingress API application/client ID |  |  |
| Adyen webhook client application ID |  |  |
| BC worker application/client ID |  |  |
| Adyen merchant account |  |  |
| Business Central environment | Sandbox | Production |
| Business Central company ID |  |  |
| Ingress Function App name and URL |  |  |
| Worker Function App name |  |  |
| Ingress and worker Key Vault names |  |  |
| Archive storage account |  |  |
| Application Insights resource |  |  |
| Extension version and package hash |  |  |

## 4. Build and verify the software

### 4.1 Azure solution

From the repository root, restore, build, and run the automated .NET tests:

```powershell
dotnet restore azure/AdyenBridge.sln
dotnet build azure/AdyenBridge.sln --no-restore --configuration Release
dotnet test azure/AdyenBridge.sln --no-build --configuration Release
```

Do not proceed unless all commands succeed. Retain the command output with the validation evidence.

### 4.2 Business Central extension

1. Open the `business-central` folder in Visual Studio Code.
2. Confirm `app.json` contains the intended version and still targets application/platform 28.0 and runtime 16.0.
3. Use **AL: Download Symbols** against the target sandbox, or confirm matching symbols exist in `.alpackages`.
4. Use **AL: Package** to compile the production extension.
5. Record the generated `.app` filename, version, and SHA-256 hash in the deployment record.

The repository's local `.vscode/launch.json`, when present, is developer-specific. Do not reuse its environment, company, page, or `ForceSync` settings for a controlled production deployment.

The separate `business-central-tests` app currently contains only a small automated state-classification suite. It supplements, but does not replace, the UAT in [testing-validation.md](testing-validation.md).

## 5. Create the Entra identities

Create separate registrations and credentials for test and production. Never reuse a client secret across environments.

### 5.1 Adyen-to-ingress OAuth applications

Create two Entra registrations for each environment:

1. **Ingress API application**
   - Expose an application permission suitable for client-credential access.
   - Use its application ID URI as the token audience, normally `api://<INGRESS_API_APP_ID>`.
   - Record its application/client ID as `ingressAuthClientId`.
2. **Adyen webhook client application**
   - Grant it application access to the ingress API and provide tenant-wide admin consent.
   - Create a client credential using the organization's approved lifetime and rotation policy.
   - Record its application/client ID as `adyenWebhookClientId`.

The Bicep deployment restricts App Service Authentication to the configured webhook client application. Use:

- Issuer: `https://login.microsoftonline.com/<TENANT_ID>/v2.0`
- Audience: the exposed ingress API application ID URI
- Token scope for the Adyen client-credential request: the ingress application ID URI with `/.default`

Store the Adyen webhook client secret only in Adyen's OAuth configuration and the organization's credential vault. It is not an application setting in this repository.

### 5.2 Azure-worker-to-Business-Central application

1. Create a confidential Entra application for the Azure worker.
2. Add the **Dynamics 365 Business Central** application permission `API.ReadWrite.All`.
3. Grant tenant-wide admin consent.
4. Create a client secret using the approved lifetime and rotation policy.
5. Record the application/client ID as `businessCentralClientId`; store the secret later as `business-central-client-secret` in the worker Key Vault.

Do not grant delegated permissions or broad Business Central user permissions to this application.

## 6. Deploy Azure infrastructure

Use different resource groups for test and production. The Bicep template creates two Function Apps, two duplicate-detecting Service Bus queues, separate host-storage accounts, a private archive container set, Application Insights backed by a 30-day Log Analytics workspace, and separate ingress/worker Key Vaults.

### 6.1 Prepare the test parameters

Copy the non-secret template and replace every `YOUR_...` placeholder:

```powershell
Copy-Item infra/test.bicepparam.example infra/test.bicepparam
```

The parameter file must contain only identifiers. Keep it out of source control if organizational policy classifies those identifiers as sensitive.

### 6.2 Validate and deploy

```powershell
az login --tenant <TENANT_ID>
az account set --subscription <SUBSCRIPTION_ID>
az group create --name <TEST_RESOURCE_GROUP> --location <AZURE_LOCATION>
az deployment group validate `
  --resource-group <TEST_RESOURCE_GROUP> `
  --template-file infra/main.bicep `
  --parameters infra/test.bicepparam
az deployment group create `
  --name adyen-reconciliation-test `
  --resource-group <TEST_RESOURCE_GROUP> `
  --template-file infra/main.bicep `
  --parameters infra/test.bicepparam
az deployment group show `
  --name adyen-reconciliation-test `
  --resource-group <TEST_RESOURCE_GROUP> `
  --query properties.outputs
```

Copy the output names and ingress URL into the deployment worksheet. Resolve any failed Key Vault or role-assignment deployment before continuing.

### 6.3 Populate Key Vault secrets

The HMAC key and Report service credential originate in Adyen. Before populating the vaults, create the Standard webhook in a disabled state using the deployed ingress URL, generate its HMAC key, and create the Report service user described in sections 9.2 and 9.3. Do not enable webhook or report delivery yet.

Use the Azure portal, a protected deployment pipeline, or another approved secret-injection method. Create exactly these secrets:

| Vault | Secret name | Value source |
|---|---|---|
| Ingress | `adyen-hmac-current` | Current Adyen Standard webhook HMAC key |
| Ingress | `adyen-hmac-previous` | Previous HMAC key retained during rotation |
| Worker | `business-central-client-secret` | Worker Entra application secret |
| Worker | `adyen-report-username` | Adyen Report service user name |
| Worker | `adyen-report-password` | Adyen Report service Basic Auth password |

The template references both HMAC secret names. On the first installation, when no previous key exists, initialize `adyen-hmac-previous` with the current key value; replace it with the former current key during the first rotation.

After creating the secrets, confirm that every Function App Key Vault reference reports a healthy resolution. Do not display or export secret values during this check.

## 7. Install and configure Business Central

Install the extension before enabling Adyen delivery so the worker API endpoints exist when messages arrive.

### 7.1 Upload the extension

1. In the Business Central Admin Center, open the sandbox environment and choose **Manage Apps**.
2. Install the generated per-tenant `.app` package and select the current environment version.
3. Wait for validation and installation to complete.
4. Open the environment and confirm that **Adyen Setup**, **Adyen Payment Method Policies**, **Imported Adyen Payments**, **Adyen Payment Exceptions**, **Adyen Inbox Entries**, and **Adyen Report Runs** are searchable.

The Admin Center is the preferred per-tenant extension deployment route. The in-client **Extension Management > Upload Extension** route may be used only if required by the tenant's current administration process.

The install codeunit creates one `Adyen Setup` record per company. Repeat the company-level configuration in every company where the extension will run.

### 7.2 Register the worker application

1. Open **Microsoft Entra Applications** in the target Business Central company.
2. Add the worker application's client ID and a recognizable description.
3. Enable the application.
4. Assign only the `ADYEN SERVICE` permission set.
5. Do not assign `SUPER`, journal-posting permissions, or interactive user permissions to the service application.

The service application can insert inbox messages and report runs. It cannot perform matching or post accounting entries.

The worker uses this company-scoped API root:

```text
https://api.businesscentral.dynamics.com/v2.0/<TENANT_ID>/<ENVIRONMENT_NAME>/api/genesisimport/adyen/v1.0/companies(<COMPANY_ID>)/
```

The entity sets are `adyenInboundMessages` and `adyenReportRuns`. Obtain the company GUID using the standard Business Central `api/v2.0/companies` endpoint or approved administration tooling, and confirm it matches `businessCentralCompanyId` in the Bicep parameters. Use an approved OAuth/API client; do not paste the worker client secret into test evidence.

### 7.3 Assign human and Job Queue permissions

- Assign `ADYEN ADMIN` to integration administrators.
- Assign `ADYEN FINANCE` to finance operators and to the Job Queue identity.
- Also grant finance operators and the Job Queue identity the standard Business Central permissions required to validate and post customer payment journals and access the configured G/L account.
- Keep extension installation rights separate from routine finance access.

### 7.4 Prepare accounting configuration

Before enabling the extension, create or approve:

1. A dedicated general journal template.
2. A dedicated automatic payment batch.
3. A separate manual-review payment batch in the same template.
4. An Adyen clearing G/L account with the required posting setup, currency policy, dimensions, and reconciliation ownership.
5. Open posting periods for the intended Adyen event dates.

Do not use a general-purpose cash-receipt batch for automatic processing.

### 7.5 Complete Adyen Setup

Open **Adyen Setup** and enter:

| Field | Required value |
|---|---|
| `Enabled` | Off until all configuration and connectivity checks are complete |
| `Merchant Account` | Exact Adyen merchant account configured in Azure |
| `Environment` | Test in sandbox; Live only in production |
| `Auto Post` | Off through all UAT and shadow cycles |
| `Journal Template Name` | Dedicated payment journal template |
| `Journal Batch Name` | Dedicated automatic batch |
| `Manual Journal Batch Name` | Separate manual-review batch |
| `Clearing G/L Account No.` | Approved Adyen clearing account |
| `Report Deadline` | Local deadline after Adyen's expected daily report generation |
| `Raw Retention Days` | Informational value aligned with Azure's default 90-day raw-webhook retention |
| `Report Retention Months` | Informational value aligned with Azure's default 400-day report retention |

The Job Queue user's time zone must be `Europe/Berlin` because the overdue-report check uses the session's date and time.

### 7.6 Configure payment methods

Open **Adyen Payment Method Policies** and add every payment-method code expected from Adyen. During UAT, enable automatic matching only for the methods actively being tested while `Auto Post` remains off. After sign-off, enable only finance-approved production methods.

An absent or disabled method produces `Unsupported payment method`; it is not automatically posted.

### 7.7 Create the Job Queue entry

1. In **Adyen Setup**, choose **Create Job Queue Entry**.
2. Review the generated entry for codeunit **Adyen Inbox Dispatcher**.
3. Confirm that it is recurring every one minute and initially `On Hold`.
4. Set the responsible user, category, earliest start time, and operational limits required by local policy.
5. Confirm the responsible user has `ADYEN FINANCE` plus standard journal-posting permissions and uses the required time zone.
6. Set the entry to **Ready** only after the setup and permission checks pass.

Each invocation processes at most 50 messages and commits each inbox result independently.

## 8. Publish the Function Apps

Retrieve the Function App names from the Bicep outputs. Publish from each project directory without uploading `local.settings.json`; the Bicep deployment and Key Vault references already supply production settings.

```powershell
Push-Location azure/src/AdyenBridge.Ingress
func azure functionapp publish <INGRESS_FUNCTION_APP_NAME>
Pop-Location

Push-Location azure/src/AdyenBridge.Worker
func azure functionapp publish <WORKER_FUNCTION_APP_NAME>
Pop-Location
```

Do not use `--publish-local-settings`.

Verify the deployments:

```powershell
az functionapp function list `
  --resource-group <TEST_RESOURCE_GROUP> `
  --name <INGRESS_FUNCTION_APP_NAME> `
  --query "[].name"
az functionapp function list `
  --resource-group <TEST_RESOURCE_GROUP> `
  --name <WORKER_FUNCTION_APP_NAME> `
  --query "[].name"
```

Expected functions are:

- Ingress: `AdyenStandardWebhook`
- Worker: `ProcessAdyenWebhook` and `ProcessAdyenReport`

Confirm that the ingress rejects an unauthenticated request, the worker has no HTTP-triggered function, the Service Bus queues have no unexpected messages, and Application Insights receives Function invocation telemetry.

## 9. Configure Adyen

Perform this section in the Adyen test merchant first.

### 9.1 Payment contract

1. Configure immediate automatic capture and prevent individual v1 requests from overriding it.
2. Send the Business Central customer number in `shopperReference`. It must fit the Business Central customer-number field; the current automatic resolver supports at most 20 characters.
3. Enable shopper additional data so `shopperReference` is included in Standard webhook notifications.

### 9.2 Standard webhook

1. Create a Standard webhook using the Bicep `ingressUrl` output.
2. Configure OAuth 2.0 client credentials using the Adyen webhook client application, tenant token endpoint, ingress audience, and `/.default` scope.
3. Confirm the webhook HMAC key matches `adyen-hmac-current` in the ingress Key Vault.
4. Enable the required event types, including successful `AUTHORISATION`, `CAPTURE_FAILED`, refunds, chargebacks, second chargebacks, and settlement reversals.
5. Test the webhook from Adyen and confirm an HTTP `202` response.

The ingress validates OAuth, HMAC, merchant account, and test/live environment before accepting the notification.

### 9.3 Daily Payment Accounting Report

1. Schedule one Payment Accounting Report for each calendar day.
2. Configure automatic `REPORT_AVAILABLE` notifications to the same Standard webhook.
3. Ensure the CSV contains these exact required columns:
   - `Merchant Account`
   - `Psp Reference`
   - `Merchant Reference`
   - `Payment Currency`
   - `Captured (PC)`
   - `Record Type`
   - `Booking Date`
   - `Shopper Reference`
4. Retain `Booking Time`, `Modification Psp Reference`, and either `Payment Method` or `Payment Method Variant` when available.
5. Use a daily filename containing exactly one `yyyy_MM_dd` date. Multi-day report ranges are rejected.
6. Confirm the Report service user uses Basic Auth and its user name/password match the worker Key Vault secrets.

The implementation uses `SentForSettle` rows and the absolute `Captured (PC)` value to confirm or backfill payments.

## 10. Enable test processing

Use this order to prevent premature posting:

1. Confirm both Functions, queues, archives, Key Vault references, and Business Central APIs are healthy.
2. Confirm Business Central setup, permissions, policies, and Job Queue identity.
3. Keep `Auto Post` off.
4. Set `Adyen Setup.Enabled` on.
5. Set the Job Queue entry to **Ready**.
6. Enable the Adyen test webhook and report schedule.
7. Execute [testing-validation.md](testing-validation.md).

If `Enabled` is off, Business Central rejects new inbound records. Do not leave Adyen delivery enabled in that state long enough for Service Bus messages to exhaust their retry count.

## 11. Shadow run and production promotion

Complete three consecutive daily test cycles with `Auto Post` off. For each cycle:

- Compare successful authorisations, imported payments, ready-to-post records, exceptions, and `SentForSettle` rows.
- Confirm the report run reaches `Processed` and every discrepancy is explained.
- Confirm Service Bus dead-letter counts are zero.
- Confirm no payment was posted automatically.
- Retain the validation evidence and approvals.

After formal sign-off:

1. Repeat the identity, Bicep, Key Vault, Function, extension, company setup, and Adyen configuration with production-specific values.
2. Leave production `Auto Post` off and the production Job Queue on hold during configuration.
3. Perform a finance-approved, controlled production smoke transaction.
4. Confirm its complete evidence chain and report confirmation.
5. Enable approved payment methods.
6. Enable `Auto Post` only with finance and operations approval.
7. Monitor Function failures, Service Bus dead-letter counts, inbox errors, payment exceptions, report discrepancies, and report overdue status during the agreed hypercare period.

## 12. Safe stop and rollback

To stop processing without destroying evidence:

1. Turn `Auto Post` off immediately.
2. Set the Adyen Job Queue entry to **On Hold**.
3. Disable Adyen Setup only after pausing webhook/report delivery or confirming the Service Bus retry window is sufficient.
4. Disable the Adyen webhook if ingestion must stop completely.
5. Preserve inbox entries, imported payments, report runs, Blob archives, queue/dead-letter contents, and posted ledger entries.
6. Correct configuration or deploy an approved higher-version extension/Function package; do not delete or manually rewrite correlation identifiers.
7. Resume in reverse order and use **Retry** only after the underlying cause is corrected.

Uninstalling the extension, deleting queues, purging blobs, or deleting posted ledger entries is not an operational rollback.

## 13. Telemetry and known v1 boundaries

The Bicep deployment connects both Azure Function Apps to Application Insights. Explicit application logs cover ingress acceptance/rejection, successful webhook-worker completion, successful report loading, and selected failures. Business Central processing results are primarily stored in the custom inbox/payment/report tables and standard ledger entries.

The AL extension defines the `ADYEN001` overdue-report event with `TelemetryScope::ExtensionPublisher`, but `business-central/app.json` does not contain an `applicationInsightsConnectionString`. Unless the packaging/deployment process injects one, do not assume that `ADYEN001` reaches an Application Insights resource. Always validate the `Report Overdue` and `Report Alert Message` fields in Adyen Setup.

Current v1 also has these intentional limits:

- Invoice matching uses customer, currency, and exact remaining amount; it does not use `Merchant Reference`.
- A normal invoice and a posted prepayment invoice are both customer-ledger entries of type `Invoice`. The extension does not distinguish them.
- Posting a customer payment does not release or otherwise update a sales order.
- Fees, payout/bank matching, exchange differences, automatic refunds, chargebacks, unapplication, and automatic reversals are outside v1.

## References

- [Architecture](architecture.md)
- [Testing and validation](testing-validation.md)
- [Operations and recovery](operations.md)
- [Azure infrastructure](../infra/README.md)
- [Microsoft: deploy a Business Central per-tenant extension](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-deploy-tenant-customization)
- [Microsoft: publish Azure Functions with Core Tools](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local#publish)
- [Adyen: automatically get reports](https://docs.adyen.com/reporting/automatically-get-reports/)
