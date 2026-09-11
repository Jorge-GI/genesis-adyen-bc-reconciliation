# Installation and setup

## 1. Install in a sandbox first

1. Compile and publish the production app to a Business Central Online 28 sandbox.
2. In **Extension Management**, open the extension settings and enable **Allow HttpClient Requests**. Do not disable BC certificate validation.
3. Assign permission sets:
   - Power Automate connection user: `ADYEN SERVICE` plus only the standard sign-in/company/connector permissions required by your tenant.
   - Job Queue user: `ADYEN PROCESSOR` plus the standard BC permissions required for customer payment posting.
   - Finance operators: `ADYEN FINANCE` plus their normal finance role.
   - Configuration administrators: `ADYEN ADMIN`; add processor or finance rights only if that person also performs those duties.
4. In **My Settings**, finance operators and configuration administrators can select the **Adyen Reconciliation** role. The role changes the home page and navigation only; it does not replace the Adyen permission sets or the user's normal Business Central finance permission sets.
5. Open **Adyen Setup**. Installation creates the singleton with Auto Post unavailable until merchants are configured; integration `Enabled` starts off.

The **Adyen Reconciliation** home page is a finance workspace modeled on the navigation structure of OPplus but has no OPplus runtime dependency. It combines Adyen reconciliation cues and quick-access tiles with the standard Accountant headline and activities, My Accounts, an Adyen-specific Job Queue card, report inbox, and notes. Navigation covers all Adyen pages plus receivables, payables, cash management, general ledger, posting history, finance setup, document creation, common journals, bank reconciliation, Find Entries, and core finance reports.

The Adyen cues distinguish payment exceptions, payments ready to post, manual journal drafts, pending and errored webhook requests, pending and errored event entries, active and errored report runs, and enabled merchants with overdue reports. **Payment Statistics** shows all-time, company-wide counts for total imported payments and posted payments, with posted payments divided into **Automatically Posted**, **Manually Posted**, and **Unclassified Posted**. Imported and posted totals intentionally overlap. Manual combines user-triggered exact-match posting and reviewed manual-journal posting; the payment list shows the detailed origin. Existing postings are intentionally not inferred or backfilled and therefore remain unclassified. **Posted Adyen Payments** identifies extension-originated postings through the retained customer ledger entry link; users can open the payment entry or use **Find Related Entries** to inspect the associated G/L and detailed ledger entries. **Posted By** and **Posted At** are read from that linked customer ledger entry rather than duplicated on the Adyen payment.

The **Adyen Job Queue Tasks** card counts only Job Queue entries that run the Adyen Dispatcher codeunit `72044`: `Error` entries appear in **Tasks Failed**, `In Process` entries appear in **Tasks In Process**, and `Ready` or `Waiting` entries appear in **Tasks In Queue**. Any nonzero failed count is red. The card and filtered **Adyen Job Queue** link are shown only when the user can read Job Queue entries. Configuration tiles and navigation links are likewise shown only when the user has the corresponding permissions. Credential management, retention cleanup, and queue creation remain on **Adyen Setup**.

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

For each merchant, choose **Payment Method Policies** from **Adyen Merchants** and add each normalized Adyen `paymentMethod`/report variant allowed to enter that merchant's automatic matching path. The unfiltered **Adyen Payment Method Policies** page shows all merchant policies. There is no company-wide fallback: a method that is absent or disabled for the payment's merchant remains a manual exception.

## 4. Configure the background job

From **Adyen Setup**, choose **Create Job Queue Entry**. Review the generated recurring one-minute entry and set it to **Ready** under the dedicated processor identity. Verify that the session's time zone matches the intended report-deadline interpretation.

The dispatcher processes bounded batches and one report download per run. Increasing frequency is preferable to very large batch sizes. Do not use **Run once (Foreground)** for this entry: the dispatcher intentionally requires the scheduled background session before processing anything.

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
- lifecycle progression, report backfills, and `Data Conflict` exceptions;
- customer, currency, exact amount, and invoice match decisions;
- overdue state separately for every merchant.

Resolve configuration and data-quality exceptions. Run the tenant UAT in [testing and validation](testing-validation.md), obtain finance approval, then enable Auto Post one merchant at a time.

## Credential rotation

1. Use **Rotate HMAC Key** with the new hexadecimal key. BC atomically moves the current key to the previous slot.
2. Activate the corresponding key in Adyen and submit signed test/live traffic.
3. Observe retries long enough to cover the webhook retry window.
4. Use **Clear Previous HMAC Key** only when old-key deliveries are no longer expected.

To rotate report credentials, use **Set Report Credentials**, retry a test report, and then retire the old credentials in Adyen. **Clear Report Credentials** removes both encrypted values.
