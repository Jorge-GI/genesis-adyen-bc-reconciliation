# Acceptance test matrix

`Automated` identifies coverage in `business-central-tests`. `Tenant UAT` requires a configured BC 28 sandbox, Power Automate, or real Adyen endpoint.

| Area | Scenario | Expected result | Level |
| --- | --- | --- | --- |
| HMAC | Known canonical vector including colon/backslash escaping | Current hexadecimal key validates | Automated |
| HMAC | Amount changed or malformed signature | Request rejected | Automated |
| HMAC | Current key rotated | Old signature accepted only through previous slot | Automated |
| Intake | Multi-item complete envelope | One raw request and one normalized event per item | Automated |
| Intake | Oversize, malformed JSON, wrong environment, disabled/unknown merchant | API transaction rejected; no raw row | Automated/UAT |
| Intake | Same flow run and same payload | Existing request returned; no duplicate | Automated |
| Intake | Same flow run with another payload hash | Conflict rejected | Automated |
| Intake | Same event retransmitted in another valid envelope | Audit event retained; payment/posting remains idempotent | Tenant UAT |
| Ordering | Older authorisation follows newer authorisation | Older data cannot overwrite newer state | Automated |
| Money | EUR/ISK, JPY/IDR, KWD | Two-, zero-, and three-decimal amounts correct | Automated |
| Merchants | Same PSP reference under two merchants | Two merchant-qualified payments | Automated |
| Merchants | Shared credentials/policy, separate journals/clearing/Auto Post | Each company/merchant boundary honored | Automated/UAT |
| Customer | Missing or blocked direct shopperReference customer | Invalid customer exception | Automated |
| Method | Method absent/disabled in company policy | Unsupported method; no auto posting | Automated |
| Invoice | No, one, or multiple equal open invoices | None, Unique Exact, or Multiple | Automated |
| Invoice | LCY blank code vs foreign currency | LCY normalized; foreign mismatch rejected | Automated |
| Invoice | Partial or overpayment | No exact match | Automated |
| Posting | Auto Post default/off | Payment retained for review | Automated/UAT |
| Posting | Auto Post on with exact invoice | Payment and clearing entry posted and invoice fully applied | Automated/UAT |
| Posting | Closed period or posting validation failure | No partial ledger entries; event error/retry retained | Automated/UAT |
| Posting | Duplicate/retry | Existing ledger link prevents another posting | Automated/UAT |
| Manual | Override customer and re-evaluate | Match recalculated without merchantReference forcing | Tenant UAT |
| Manual | Create draft twice | One linked line only | Automated/UAT |
| Manual | Delete draft | Payment returns to prior state | Automated/UAT |
| Manual | Post draft | Customer ledger entry linked; manually reconciled | Automated/UAT |
| Lifecycle | Capture failure/refund/chargeback/second chargeback/settlement reversal | Reversal Required; no auto reversal | Automated/UAT |
| Report URL | HTTP, custom port, deceptive host | Download rejected | Automated |
| Report HTTP | Mock success/failure/empty/oversize | Content loaded or deterministic error | Automated |
| Report file | Filename has zero or two `yyyy_MM_dd` dates | Load rejected | Automated |
| CSV | Reordered case-insensitive headers, extra fields, quoted comma | Parsed correctly | Automated |
| CSV | Missing header, bad date/amount, wrong merchant, partial load | Report never becomes Ready | Automated |
| Report identity | Same merchant/report ID or same file rows retried | Run/rows idempotent | Automated/UAT |
| Reconcile | SentForSettle finds webhook payment | Confirmed without overwriting source data | Automated/UAT |
| Reconcile | SentForSettle has no payment | Backfilled through normal match/Auto Post path | Automated/UAT |
| Reconcile | Customer/currency/amount/adverse difference | Discrepancy retained; authoritative data unchanged | Automated |
| Deadline | Two enabled merchants miss daily report | Separate overdue state; one alert per overdue period | Automated/UAT |
| Retry | Raw/event/report worker failure then correction | Retry count/error retained; corrected unit succeeds independently | Tenant UAT |
| Retention | Raw >90 days/report >13 months | Only BLOB content purged; metadata/events/payments/ledger links remain | Automated |
| Permissions | Service identity calls create API then attempts process/post | Create allowed; process/post denied | Tenant UAT |
| Flow | BC success/failure | `[accepted]` only after persistence; generic non-2xx otherwise | Tenant UAT |
| Shadow | Three days with Auto Post off | Counts, reports, backfills, matches, and exceptions approved by finance | Tenant UAT |
