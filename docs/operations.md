# Operations

## Normal monitoring

Monitor these BC pages and the Job Queue:

- **Adyen Webhook Requests**: accepted envelopes, item counts, normalization status, retries, and raw-content retention.
- **Adyen Event Entries**: webhook/report events, lifecycle status, source links, retries, and errors.
- **Adyen Report Runs**: merchant/date, download/load state, hashes, row counts, discrepancies downstream, and retained-content state.
- **Imported Adyen Payments** and **Adyen Payment Exceptions**: matches, posting/application, backfills, report confirmation, data conflicts, and finance-review cases.
- **Adyen Merchants**: last ready report date and per-merchant overdue message.

An unchanged `Report Overdue` flag emits one warning when an overdue period begins, rather than logging on every dispatcher run.

## Status and retry behavior

Raw requests and normalized events move from `Received` to `Processing`, then `Processed`, `Ignored`, or `Error`. Report runs move through `Requested`, `Downloading`, `Loading`, `Ready`, `Processing`, and `Processed`; any unit may finish as `Error`.

Each unit runs in a separate transaction. A failed unit is rolled back, its retry count increases, and its error is retained. After correcting the cause:

- use **Retry** on a webhook request to normalize its retained BLOB again;
- use **Retry** on an event to re-run lifecycle/matching logic;
- use **Retry** on a report run to download and load it again.

A purged raw/report BLOB cannot be retried from BC. Obtain and submit/download the source again under a new source delivery when policy permits.

## Safe stop and recovery

To stop accounting but keep accepting webhooks, set the Adyen Job Queue entry to **On Hold** and leave integration Enabled. Raw requests continue to validate and accumulate. Turn Auto Post off for every merchant before resuming if finance wants a review-only recovery.

Setting integration **Enabled** off makes BC reject new submissions, so Power Automate returns failure and Adyen retries. Use that only when rejecting ingress is intentional.

Recovery sequence:

1. Correct setup, permission, customer, journal, period, credential, network, or report-format issues.
2. Keep Auto Post off if the backlog has not been reviewed.
3. Retry errored reports before dependent report events; retry raw requests before their events.
4. Set the Job Queue to Ready and watch counts/statuses until the backlog clears.
5. Review `Reversal Required`, `Data Conflict`, report discrepancies, and manual journal drafts.
6. Re-enable Auto Post per merchant after finance approval.

## Manual review

Finance may set **Resolved Customer No.** as an override and choose **Re-evaluate Match**. This never uses merchant reference to force a match. If no safe exact automatic match exists, **Create Manual Journal Line** creates one linked draft in the merchant's manual batch.

Deleting that unposted line resets the payment to its prior state. Posting it records the resulting customer ledger entry and marks the payment manually reconciled. A payment already linked to a posted entry cannot create another manual draft.

Adverse lifecycle events always require an explicit finance decision outside this extension; no automatic refund, chargeback, or settlement-reversal journal is created.

## Retention

Cleanup runs at most once per day from the dispatcher and may also be started from setup. Defaults:

- raw webhook BLOB: 90 days from received timestamp;
- report CSV BLOB: 13 months from report date.

Only BLOB content is cleared. Hashes, normalized events, statuses, errors, payment/report metadata, and ledger links remain for audit.

## Common failure causes

| Symptom | Check |
| --- | --- |
| API rejection | Enabled flag, test/live value, merchant spelling/enabled state, payload size, complete envelope, HMAC key/signature. |
| Report download error | outbound HTTP enabled, HTTPS URL, exact allowlist, no custom port, report credentials, file limit, Adyen access. |
| Report load error | filename has exactly one `yyyy_MM_dd`, required headers, merchant consistency, date/amount syntax, valid CSV quoting. |
| No automatic match | method policy, direct shopperReference/customer mapping, blocked customer, normalized currency, exact remaining amount, unique invoice. |
| Posting error | merchant batches/clearing account, posting date/period permissions, journal/posting permissions, invoice still open and unchanged. |
| Reversal Required | inspect the adverse event and perform the approved finance process manually. |
