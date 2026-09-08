# Installation and setup

## 1. Install in a sandbox first

1. Compile and publish the production app to a Business Central Online 28 sandbox.
2. In **Extension Management**, open the extension settings and enable **Allow HttpClient Requests**. Do not disable BC certificate validation.
3. Assign permission sets:
   - Power Automate connection user: `ADYEN SERVICE` plus only the standard sign-in/company/connector permissions required by your tenant.
   - Job Queue user: `ADYEN PROCESSOR` plus the standard BC permissions required for customer payment posting.
   - Finance operators: `ADYEN FINANCE` plus their normal finance role.
   - Configuration administrators: `ADYEN ADMIN`; add processor or finance rights only if that person also performs those duties.
4. Open **Adyen Setup**. Installation creates the singleton with Auto Post unavailable until merchants are configured; integration `Enabled` starts off.

## 2. Configure company-wide integration settings

On **Adyen Setup**:

1. Choose `Test` or `Live`. Keep test and live in separate BC environments and Power Automate flows.
2. Review limits. Defaults are 1 MiB per webhook, 50 MiB per report, and 50 messages per dispatcher run.
3. Set the local daily report deadline used by the Job Queue session.
4. Keep raw webhook retention at 90 days and report-file retention at 13 months unless governance requires another value. Cleanup removes BLOB content only.
5. Configure a comma-separated report host allowlist. Defaults are `ca-test.adyen.com,ca-live.adyen.com`; narrow it for the selected environment where possible.
6. Use **Set Current HMAC Key** and enter the 64-character hexadecimal HMAC key from Adyen.
7. Use **Set Report Credentials** for the shared Adyen report Basic Auth account.
8. Use **Test Stored Credentials** to confirm encrypted values are readable. This does not make a remote login; retry a real test report to validate Adyen access.

Secret actions accept values but never display stored values. Credential-presence fields are status flags only.

## 3. Configure merchants and policies

For every merchant account expected in this BC company, add **Adyen Merchants** data with the exact case-sensitive account value sent by Adyen:

- enable the merchant;
- select a general journal template;
- select separate automatic and manual payment batches;
- select the Adyen clearing G/L account;
- leave **Auto Post** off.

In **Adyen Payment Method Policies**, add each normalized Adyen `paymentMethod`/report variant allowed to enter the automatic matching path. The policy is company-wide. A method not enabled remains a manual exception.

## 4. Configure the background job

From **Adyen Setup**, choose **Create Job Queue Entry**. Review the generated recurring one-minute entry and set it to **Ready** under the dedicated processor identity. Verify that the session's time zone matches the intended report-deadline interpretation.

The dispatcher processes bounded batches and one report download per run. Increasing frequency is preferable to very large batch sizes.

## 5. Configure ingress

After credentials, merchants, policies, and the Job Queue are ready, set integration **Enabled** on **Adyen Setup**. Create one flow per company using [the Power Automate specification](power-automate.md). Point the Adyen test Standard webhook to the flow URL, use the same HMAC key, and send a test notification. Confirm:

- the flow returns `200`, `text/plain`, `[accepted]`;
- one **Adyen Webhook Request** appears;
- the Job Queue creates **Adyen Event Entries**;
- a successful authorisation creates one merchant-qualified **Imported Adyen Payment**.

## 6. Three-day shadow run

Keep Auto Post off for at least three complete business days. Each day compare:

- webhook request and event counts against Adyen;
- report readiness and relevant-row counts;
- report confirmations, backfills, and discrepancies;
- customer, currency, exact amount, and invoice match decisions;
- overdue state separately for every merchant.

Resolve configuration and data-quality exceptions. Run the tenant UAT in [testing and validation](testing-validation.md), obtain finance approval, then enable Auto Post one merchant at a time.

## Credential rotation

1. Use **Rotate HMAC Key** with the new hexadecimal key. BC atomically moves the current key to the previous slot.
2. Activate the corresponding key in Adyen and submit signed test/live traffic.
3. Observe retries long enough to cover the webhook retry window.
4. Use **Clear Previous HMAC Key** only when old-key deliveries are no longer expected.

To rotate report credentials, use **Set Report Credentials**, retry a test report, and then retire the old credentials in Adyen. **Clear Report Credentials** removes both encrypted values.
