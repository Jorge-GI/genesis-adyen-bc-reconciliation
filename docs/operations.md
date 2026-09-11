# Operations

## Normal monitoring

The **Adyen Reconciliation** role provides the extension's central finance workspace. Its Adyen cues show payment exceptions, payments ready to post, manual journal drafts, pending and errored webhook requests, pending and errored events, active and errored report runs, and enabled merchants with overdue reports. **Payment Statistics** shows the all-time imported total and the posted total for the current company, then divides posted payments into automatic, manual, and unclassified routes without attention or error styling. Imported and posted totals overlap because a posted payment remains an imported payment. **Manually Posted** combines **Manual Exact Match** and **Manual Journal**; use the detailed page to distinguish them. Choose a cue to open the corresponding page with the exact filter already applied. Exceptions, manual drafts, and overdue merchants are highlighted for attention; processing errors are highlighted as unfavorable.

Use **Posted Adyen Payments** to audit entries posted by the extension. Business Central removes journal lines after posting, so the page uses the customer ledger entry number retained on the imported payment as the durable link. **Posting Origin** is `Automatic` for the payment-state Auto Post route, `Manual Exact Match` for the page action, `Manual Journal` for a reviewed draft, and `Unclassified` when no posting route has been recorded. The origin is written only when a non-preview posting creates the customer ledger entry; a preview, failed posting, or deleted unposted draft does not classify the payment. **Posted By** and **Posted At** come from the linked customer ledger entry's existing audit fields. **Open Posted Payment** opens that customer ledger entry. **Find Related Entries** uses its document number and posting date to show all associated posted records, including G/L and detailed ledger entries available to the user.

Use the **Reconcile**, **Monitor**, and **Configure** tiles for the most common Adyen destinations. The operational webhook, event, payment, exception, posted-payment, report-run, and lifecycle pages open newest first by default. **Imported Adyen Payments** and **Adyen Payment Exceptions** show **Created At UTC** as their first column and sort by when the payment record was created in Business Central from every Role Center entry point. Later lifecycle updates do not move older payments to the top. The exception-status, Ready-to-Post, and manual-draft filters remain applied. **Webhook Requests** and **Event Entries** in Monitor open their complete history without a status filter; the pending and error cues retain their status filters. Users can still change the sort order or use a saved personal view. The navigation menu also exposes all eight Adyen pages and the standard Business Central receivables, payables, cash-management, general-ledger, history, setup, creation, processing, and core-reporting workflows allowed by the user's finance permissions. **Adyen Job Queue** opens Job Queue Entries filtered to codeunit `72044` only. Credential changes, retention cleanup, and queue creation continue to be performed from **Adyen Setup**.

The **Adyen Job Queue Tasks** card shows only dispatcher codeunit `72044`. **Tasks Failed** counts `Error`, **Tasks In Process** counts `In Process`, and **Tasks In Queue** counts `Ready` or `Waiting`. Any failed count above zero is red. Each cue drills down to the same dispatcher and status filter; users without Job Queue Entry read permission do not see the card.

Monitor these BC pages and the Job Queue:

- **Adyen Webhook Requests**: accepted envelopes, item counts, normalization status, retries, and raw-content retention.
- **Adyen Event Entries**: webhook/report events, lifecycle status, source links, retries, errors, Adyen's original reason, and BC's disposition reason.
- **Adyen Report Runs**: merchant/date, download/load state, hashes, row counts, discrepancies downstream, and retained-content state. Choose **Imported Events**, or drill down on **External Report ID** or **Loaded Row Count**, to open the events loaded from the selected report run.
- **Imported Adyen Payments**, **Adyen Payment Exceptions**, and **Posted Adyen Payments**: newest Adyen lifecycle, independent BC workflow status, matches, posting/application, backfills, data conflicts, and finance-review cases. Drill down on **PSP Reference** or **Adyen Lifecycle Status** to open the payment's newest-first lifecycle audit trail.
- **Adyen Merchants**: last ready report date and per-merchant overdue message.
- **Adyen Payment Method Policies**: merchant-qualified method eligibility for automatic matching and posting.

An unchanged `Report Overdue` flag emits one warning when an overdue period begins, rather than logging on every dispatcher run.

## Status and retry behavior

Raw requests and normalized events move from `Received` to `Processing`, then `Processed`, `Ignored`, or `Error`. Report runs move through `Requested`, `Downloading`, `Loading`, `Ready`, `Processing`, and `Processed`; any unit may finish as `Error`.

For events, **Adyen Reason** is source data received from Adyen. **Disposition Reason** is BC-generated audit metadata explaining why an event was ignored or why a valid event completed as an intentional no-op. A successfully applied event has a blank disposition reason. **Last Error** remains reserved for retryable processing failures.

The payment drilldown shows every associated event, not only state changes. **Lifecycle Effect** distinguishes `Changed`, `Applied without change`, `Not applied`, and `Unknown`. Previous and resulting lifecycle values are recorded only after a successful event-worker transaction. `Unknown` means that no processing outcome has been recorded; a previous or resulting lifecycle is also `Unknown` when no payment lifecycle was available at that point. Choose **Open Source** to open the exact webhook request or report run; retained metadata remains available even when retention has purged the raw JSON or CSV.

Webhook requests and individual events each run in a separate transaction. Report ingestion uses a durable preparation transaction followed by an atomic loading transaction: after a structurally valid CSV is downloaded, BC retains its content, report date, total-row count, and complete relevant-row count with a loaded-row count of zero. If row validation then fails, all event rows from that loading attempt are rolled back while the prepared content and counts remain available on the errored report. The retry count increases and the error is retained. After correcting the cause:

The report must follow Adyen's [Payment Accounting Report specification](https://docs.adyen.com/reporting/invoice-reconciliation/payment-accounting-report): `Booking Date` is `YYYY-MM-DD HH:MM:SS`, and `TimeZone` is required. `CET` is converted to UTC by subtracting one hour and `CEST` by subtracting two hours. Blank and unsupported zones fail the relevant row; invalid timestamps or zones on irrelevant rows are ignored. A separate `Booking Time` column, if present, is ignored.

- use **Retry** on a webhook request to normalize its retained BLOB again;
- use **Retry** on an event to re-run lifecycle/matching logic;
- use **Retry** on a report run to download and load it again.

A purged raw webhook BLOB cannot be retried from BC. A purged report can be queued for a fresh background download while its retained Adyen URL remains valid; otherwise obtain another source delivery from Adyen.

## Safe stop and recovery

To stop accounting but keep accepting webhooks, set the Adyen Job Queue entry to **On Hold** and leave integration Enabled. Raw requests continue to validate and accumulate. Turn Auto Post off for every merchant before resuming if finance wants a review-only recovery.

Setting integration **Enabled** off makes BC reject new submissions, so Power Automate returns failure and Adyen retries. Use that only when rejecting ingress is intentional.

Recovery sequence:

1. Correct setup, permission, customer, journal, period, credential, network, or report-format issues.
2. Keep Auto Post off if the backlog has not been reviewed.
3. Retry errored reports before dependent report events; retry raw requests before their events.
4. Set the Job Queue to Ready and watch counts/statuses until the backlog clears.
5. Review `Reversal Required`, including cancelled or expired authorisations, `Data Conflict`, and manual journal drafts.
6. Re-enable Auto Post per merchant after finance approval.

## Manual review

Finance may set **Resolved Customer No.** as an override and choose **Re-evaluate Match**. This never uses merchant reference to force a match. If no safe exact automatic match exists, **Create Manual Journal Line** creates one linked draft in the merchant's manual batch.

Deleting that unposted line resets the payment to its prior state without changing its posting origin. Posting it records the resulting customer ledger entry, marks the payment manually reconciled, and records `Manual Journal` as the origin. Choosing **Post Exact Match** records `Manual Exact Match`; the payment-state Auto Post path records `Automatic`. A payment already linked to a posted entry cannot create another manual draft.

Adverse lifecycle events, including successful cancellation and expiry after authorisation, always require an explicit finance decision outside this extension; no automatic refund, chargeback, or settlement-reversal journal is created. `REFUND` and `SentForRefund` remain audit-only until PAR supplies the financially meaningful `Refunded` outcome. A recovery can advance Adyen Lifecycle Status but does not clear `Reversal Required`.

Use [Adyen payment lifecycle and Business Central behavior](payment-lifecycle.md) to interpret every tracked outcome, intentionally ignored intermediate, and possible next state.

## Retention

Cleanup runs at most once per day from the dispatcher and may also be started from setup. Defaults:

- raw webhook BLOB: 90 days from received timestamp;
- report CSV BLOB: 13 months from report date.

Only downloaded report content with a populated report date is eligible for report retention. Pending and failed downloads with no content are not marked purged. Cleanup clears only eligible BLOB content; hashes, normalized events, statuses, errors, payment/report metadata, and ledger links remain for audit.

## Common failure causes

| Symptom | Check |
| --- | --- |
| API rejection | Enabled flag, test/live value, merchant spelling/enabled state, payload size, complete envelope, HMAC key/signature. |
| Report download error | outbound HTTP enabled, HTTPS URL, exact allowlist, no custom port, report credentials, file limit, Adyen access. |
| Invalid stream length reports the configured limit plus one | Install Adyen Reconciliation 1.0.0.6 or later, then retry the report. Do not change the report-file limit to work around this downloader defect. |
| Report says downloads require a background session | set the Adyen Job Queue Entry to **Ready** and let the scheduler run it; do not use **Run once (Foreground)**. Then retry the report. |
| Report load error | filename has exactly one `yyyy_MM_dd`, required amount/`Booking Date`/`TimeZone` headers, merchant consistency, exact `YYYY-MM-DD HH:MM:SS` syntax, `CET` or `CEST`, amount syntax, and valid CSV quoting. |
| No automatic match | policy for the payment's exact merchant and method, direct shopperReference/customer mapping, blocked customer, normalized currency, exact remaining amount, unique invoice. |
| Posting error | merchant batches/clearing account, posting date/period permissions, journal/posting permissions, invoice still open and unchanged. |
| Reversal Required | inspect the adverse event, including cancellation or expiry of an authorised payment, and perform the approved finance process manually. |
| Ignored or processed event with no payment change | inspect **Disposition Reason** for the BC decision and **Adyen Reason** for the source explanation. |
