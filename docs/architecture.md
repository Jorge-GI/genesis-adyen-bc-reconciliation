# Architecture

## Boundary and ownership

Power Automate owns only public HTTP ingress and the synchronous response to Adyen. Business Central owns all business and security decisions after the payload reaches the connector.

```text
Adyen Standard webhook
        |
        v
Power Automate (one flow per BC company)
        |
        v
POST genesisimport/adyen/v1.0/adyenWebhookRequests
        |
        +-- synchronous: size + JSON + environment + merchant + HMAC + atomic raw insert
        |
        v
BC Job Queue dispatcher
        |
        +-- raw request worker -> normalized webhook events
        +-- report worker -> HTTPS allowlist + Basic Auth + CSV BLOB + normalized rows
        +-- event worker -> lifecycle state + matching + optional posting/application
        +-- deadline monitor + content-only retention
```

There are no runtime services between Power Automate and BC and no external persistence tier.

## Data model

| Record | Identity and purpose |
| --- | --- |
| Adyen Setup | Company singleton with environment, limits, report host allowlist/deadline, retention, and credential-presence flags. |
| Adyen Merchant | Merchant account key with enabled state, automatic/manual journal batches, clearing account, Auto Post, last-ready report, and overdue state. |
| Adyen Webhook Request | Auto-number plus unique payload SHA-256, BLOB envelope, received/processed timestamps, correlation, status, retries, and error. |
| Adyen Event Entry | SHA-256 transport and logical identities for webhook items and report rows, normalized payment PSP reference, exact before/after lifecycle effect for newly processed events, status, retries, and source links. This is the authoritative source-and-time audit trail. |
| Adyen Report Run | Merchant plus unique external report ID, URL, original CSV BLOB, file hash, date/counts/status/retries, and audit timestamps. |
| Imported Adyen Payment | Unique merchant plus original PSP reference, current Adyen lifecycle projection, independent BC workflow state, immutable source data, customer/match state, journal link, and ledger link. |
| Adyen Merchant Method Policy | Merchant account plus payment method allowlist controlling eligibility for automatic matching/posting. |

Current/previous HMAC keys and the shared report username/password are `SecretText` values in encrypted, company-scoped `IsolatedStorage`. They are never fields and cannot be read back through a page or API.

## Integrity and transaction boundaries

- The raw request API accepts the JSON envelope through a transient, unsized API-page text property because the Power Automate connector cannot write a BC BLOB as a normal record field. BC writes that text as UTF-8 into the raw-request BLOB, validates every notification item, and commits one insert. It performs no journal work.
- A supplied Power Automate flow-run ID may be retried with the same payload only. Reuse with another payload hash is rejected. An identical payload delivered through another run resolves idempotently to the retained raw request.
- Payload, transport, logical-event, report-file, and report-row identities use SHA-256. Webhook retransmissions remain auditable while the merchant-qualified payment key prevents duplicate accounting.
- The dispatcher invokes dedicated `Codeunit.Run` workers. Each raw request and event is its own database transaction. Report ingestion uses one transaction to download and prepare retained content/counts and a second transaction to load all normalized rows atomically. A failed loading transaction rolls back its event rows before the dispatcher records retry/error state, while the prepared report metadata remains committed.
- Payment Accounting Report rows use Adyen's combined `Booking Date` format (`YYYY-MM-DD HH:MM:SS`) and `TimeZone`. The parser treats the supplied `CET` or `CEST` code as authoritative, subtracts one or two hours respectively, and stores the result in `Occurred At UTC`; it does not infer daylight-saving rules. A legacy `Booking Time` column is an ignored extra field.
- The dispatcher rejects **Run once (Foreground)** before changing any inbox record. Scheduled Job Queue executions run in a background session and may download reports.
- A report is `Ready` only after every relevant row has loaded. Report events are not eligible for reconciliation while the run is `Requested`, `Downloading`, `Loading`, or `Error`.
- Posting and exact invoice application run under `CommitBehavior::Error`. The posted customer entry is linked through the Adyen payment SystemId carried on the journal line.

## Matching and lifecycle policy

`shopperReference` maps directly to Customer No. An automatic match requires an enabled payment-method policy for the payment's exact merchant account, an unblocked customer, and exactly one open invoice whose normalized currency and remaining amount equal the positive payment amount. Policies have no global fallback or inheritance. `merchantReference` is audit data only.

Successful `AUTHORISATION` webhooks and PAR `Authorised` rows use the normal creation, matching, and optional posting path. `SentForSettle` is retained as a normal-flow milestone, and `Settled` records positive completion; either can backfill a missing payment. Lifecycle events only update the current projection when they are chronologically newer. Failed authorisations and unsupported intermediates are audited without changing a payment.

Successful cancellations, expiries, capture failures, completed/failed/reversed refunds, chargebacks, second chargebacks, chargeback reversals, and settlement reversals set `Reversal Required`; no automatic reversing entry is created. `REFUND` initiation is intentionally audit-only until PAR reports `Refunded`. A recovery updates the lifecycle projection but never automatically clears finance review. Positive report data that disagrees with the retained payment sets `Data Conflict`, with `Reversal Required` taking precedence.

See [Adyen payment lifecycle and Business Central behavior](payment-lifecycle.md) for the complete flow, event matrix, amount source, and exclusions.

## Security

- The Power Automate identity receives `ADYEN SERVICE`, which can read setup/merchant allowlists and insert raw requests through the API but cannot normalize, reconcile, or post.
- The Job Queue identity receives `ADYEN PROCESSOR` plus the tenant's standard permissions required to post customer payments.
- Finance users receive `ADYEN FINANCE`; administrators receive `ADYEN ADMIN` and assign processor/finance rights only where needed.
- Report URLs must use HTTPS, omit custom ports, and match the configured host or its subdomain. BC's normal outbound certificate validation remains enabled. File size is checked before persistence.
- The extension never initiates report HTTP requests from a page action; downloads occur through the background report worker.

## Deliberate exclusions

Partial/multiple captures and refunds, installments, authorisation adjustments, external payments, Adyen orders, unreferenced POS refunds, payout/settlement-detail accounting, fees, bank matching, complete dispute-case management, exchange differences, automatic refund/chargeback/reversal posting, and sales-order release are outside this version.
