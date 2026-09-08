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
| Adyen Event Entry | SHA-256 transport and logical identities for webhook items and report rows, normalized payment/lifecycle data, status, retries, and source links. |
| Adyen Report Run | Merchant plus unique external report ID, URL, original CSV BLOB, file hash, date/counts/status/retries, and audit timestamps. |
| Imported Adyen Payment | Unique merchant plus original PSP reference, immutable source data, customer/match state, report state, journal link, and ledger link. |
| Adyen Payment Method Policy | Company-wide allowlist controlling methods eligible for automatic matching/posting. |

Current/previous HMAC keys and the shared report username/password are `SecretText` values in encrypted, company-scoped `IsolatedStorage`. They are never fields and cannot be read back through a page or API.

## Integrity and transaction boundaries

- The raw request API validates every notification item before one insert is committed. It performs no journal work.
- A supplied Power Automate flow-run ID may be retried with the same payload only. Reuse with another payload hash is rejected. An identical payload delivered through another run resolves idempotently to the retained raw request.
- Payload, transport, logical-event, report-file, and report-row identities use SHA-256. Webhook retransmissions remain auditable while the merchant-qualified payment key prevents duplicate accounting.
- The dispatcher invokes dedicated `Codeunit.Run` workers. Each raw request, report, and event is its own database transaction. On error the worker transaction rolls back before the dispatcher records retry/error state.
- A report is `Ready` only after every relevant row has loaded. Report events are not eligible for reconciliation while the run is `Requested`, `Downloading`, `Loading`, or `Error`.
- Posting and exact invoice application run under `CommitBehavior::Error`. The posted customer entry is linked through the Adyen payment SystemId carried on the journal line.

## Matching and lifecycle policy

`shopperReference` maps directly to Customer No. An automatic match requires an enabled payment-method policy, an unblocked customer, and exactly one open invoice whose normalized currency and remaining amount equal the positive payment amount. `merchantReference` is audit data only.

Successful `AUTHORISATION` and report-backfilled `SentForSettle` rows use the same payment path. Failed authorisations are ignored. Capture failures, refunds, chargebacks, second chargebacks, and settlement reversals set `Reversal Required`; no automatic reversing entry is created. Conflicting retransmissions are quarantined as `Data Conflict` without overwriting retained authoritative data.

## Security

- The Power Automate identity receives `ADYEN SERVICE`, which can read setup/merchant allowlists and insert raw requests through the API but cannot normalize, reconcile, or post.
- The Job Queue identity receives `ADYEN PROCESSOR` plus the tenant's standard permissions required to post customer payments.
- Finance users receive `ADYEN FINANCE`; administrators receive `ADYEN ADMIN` and assign processor/finance rights only where needed.
- Report URLs must use HTTPS, omit custom ports, and match the configured host or its subdomain. BC's normal outbound certificate validation remains enabled. File size is checked before persistence.
- The extension never initiates report HTTP requests from a page action; downloads occur through the background report worker.

## Deliberate exclusions

Settlement-detail accounting, fees, payout/bank matching, exchange differences, automatic refund/chargeback/reversal posting, and sales-order release are outside this version.
