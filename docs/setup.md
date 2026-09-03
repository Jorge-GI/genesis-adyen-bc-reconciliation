# Setup

## 1. Adyen

1. Configure immediate automatic capture and ensure it cannot be overridden for v1 payment requests.
2. Set the Business Central customer number as `shopperReference`.
3. Enable shopper details/additional data so `shopperReference` is present in Standard webhooks.
4. Configure a Standard webhook pointing to the deployed ingress URL.
5. Configure OAuth 2.0 and generate an HMAC key. Keep the previous HMAC key during rotations.
6. Enable the required lifecycle events, including `CAPTURE_FAILED`, refunds, and chargebacks.
7. Schedule the daily Payment Accounting Report and add `Shopper Reference` to its columns.
8. Create a report-service credential for automated downloads.

## 2. Azure

1. Deploy `infra/main.bicep` independently for test and production.
2. Put the current/previous HMAC keys in the ingress Key Vault. Put the report credentials and BC client secret in the worker Key Vault.
3. Publish `AdyenBridge.Ingress` and `AdyenBridge.Worker` to their respective Function Apps.
4. Confirm the ingress has webhook-queue send, its isolated host-storage access, and read access only to its HMAC vault.
5. Confirm the worker has queue send/receive, its isolated host storage, Blob archive, read access to its worker vault, and outbound BC access.
6. Configure alerts for Function failures, latency near ten seconds, and Service Bus dead-letter counts.

## 3. Business Central

1. Publish and install `business-central/Adyen Reconciliation.app` in a sandbox.
2. Add the Azure worker Entra application on the **Microsoft Entra Applications** page and assign `ADYEN SERVICE` only.
3. Assign `ADYEN ADMIN` to integration administrators and `ADYEN FINANCE` to finance operators. Users still need the standard Business Central permissions required to post payment journals.
4. Open **Adyen Setup** and configure the merchant, environment, dedicated journal template, separate automatic/manual batches, clearing account, and report deadline.
5. Keep **Auto Post** disabled.
6. Add every accepted method on **Adyen Payment Method Policies**. Enable it only after an end-to-end test.
7. Ensure the Job Queue session/user uses the Europe/Berlin time zone and has `ADYEN FINANCE` plus the standard journal-posting permissions. Then use **Create Job Queue Entry**, review the generated recurring one-minute entry, and set it to Ready.
8. Complete a shadow run comparing webhooks, accounting reports, journal postings, and exception queues before enabling Auto Post.
