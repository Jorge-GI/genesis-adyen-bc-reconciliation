# Azure infrastructure

`main.bicep` creates separate ingress and worker Function Apps, two duplicate-detecting Service Bus queues, a dedicated archive account, isolated host-storage accounts, Application Insights, and separate RBAC-enabled Key Vaults for ingress and worker secrets.

The archive account applies lifecycle deletion after 90 days for raw webhooks and 400 days for original reports by default. Override `rawWebhookRetentionDays` and `reportRetentionDays` to match the approved retention policy, and keep the informational values in Business Central setup aligned.

Before deployment, create the Entra registrations for:

1. Adyen-to-ingress OAuth. `ingressAuthClientId` identifies the API registration and `adyenWebhookClientId` restricts accepted tokens to the client application used by Adyen. Configure the issuer and audience, then give the Adyen Standard webhook the corresponding token endpoint, client ID, client secret, and scope.
2. Worker-to-Business Central S2S. Grant `Dynamics 365 Business Central/API.ReadWrite.All`, consent it, add the application in Business Central, and assign only `ADYEN SERVICE`.

After deployment, put only the current and previous HMAC keys in the ingress Key Vault. Put the Business Central client secret and Adyen report credentials in the worker Key Vault. Secret values are intentionally not accepted as Bicep parameters.

Deploy test and production into different resource groups with different merchant accounts, OAuth registrations, HMAC keys, queues, storage, and Business Central environments.

Copy `test.bicepparam.example` or `production.bicepparam.example`, replace every `YOUR_...` value, and keep the resulting environment-specific parameter file out of source control if it contains organizational identifiers. The parameter templates contain no secrets.

The worker app contains no HTTP-triggered functions. The ingress identity cannot access the archive account or worker vault and has no Business Central or Adyen report credential settings. Each Function App can access only its own host-storage account.
