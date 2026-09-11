# Acceptance test matrix

`Automated` identifies coverage in `business-central-tests`. `Tenant UAT` requires a configured BC 28 sandbox, Power Automate, or real Adyen endpoint.

| Area | Scenario | Expected result | Level |
| --- | --- | --- | --- |
| HMAC | Known canonical vector including colon/backslash escaping | Current hexadecimal key validates | Automated |
| HMAC | Amount changed or malformed signature | Request rejected | Automated |
| HMAC | Current key rotated | Old signature accepted only through previous slot | Automated |
| Intake | Multi-item complete envelope | One raw request and one normalized event per item | Automated |
| Intake | Connector JSON text input | UTF-8 JSON is retained in the raw-request BLOB; empty input is rejected | Automated/UAT |
| Intake | Oversize, malformed JSON, wrong environment, disabled/unknown merchant | API transaction rejected; no raw row | Automated/UAT |
| Intake | Same flow run and same payload | Existing request returned; no duplicate | Automated |
| Intake | Same flow run with another payload hash | Conflict rejected | Automated |
| Intake | Same event retransmitted in another valid envelope | Audit event retained; payment/posting remains idempotent | Tenant UAT |
| Ordering | Older or duplicate lifecycle event follows a newer state | Event remains audited but cannot regress lifecycle or overwrite payment data | Automated |
| Disposition | Failed/missing-success authorisation or unsupported webhook/report event | Ignored with a distinct BC disposition reason; Adyen reason remains unchanged | Automated |
| Disposition | Duplicate, stale, reversal-blocked, or unsuccessful adverse event | Processed no-op with a specific disposition reason | Automated |
| Disposition | Successful retry after an earlier disposition | Stale disposition is cleared; successfully applied event remains blank | Automated |
| Money | EUR/ISK, JPY/IDR, KWD | Two-, zero-, and three-decimal amounts correct | Automated |
| Merchants | Same PSP reference under two merchants | Two merchant-qualified payments | Automated |
| Merchants | Shared credentials, merchant-specific policies, separate journals/clearing/Auto Post | Each company/merchant boundary honored | Automated/UAT |
| Customer | Missing or blocked direct shopperReference customer | Invalid customer exception | Automated |
| Method | Same method enabled for one merchant and absent/disabled for another | Only the enabled merchant can match or auto post; no global fallback | Automated/UAT |
| Invoice | No, one, or multiple equal open invoices | None, Unique Exact, or Multiple | Automated |
| Invoice | LCY blank code vs foreign currency | LCY normalized; foreign mismatch rejected | Automated |
| Invoice | Partial or overpayment | No exact match | Automated |
| Posting | Auto Post default/off | Payment retained for review | Automated/UAT |
| Posting | Auto Post on with exact invoice | Payment and clearing entry posted and invoice fully applied | Automated/UAT |
| Posting origin | Payment-state Auto Post, Post Exact Match, and manual draft posting | Origins are Automatic, Manual Exact Match, and Manual Journal respectively | Automated/UAT |
| Posting origin | Preview, posting failure, or deletion of an unposted manual draft | No customer ledger link or posting origin is recorded | Automated/UAT |
| Posting origin | New payment has not been posted | Origin remains Unclassified until a real posting creates the linked customer ledger entry | Automated/UAT |
| Posting | Closed period or posting validation failure | No partial ledger entries; event error/retry retained | Automated/UAT |
| Posting | Duplicate/retry | Existing ledger link prevents another posting | Automated/UAT |
| Manual | Override customer and re-evaluate | Match recalculated without merchantReference forcing | Tenant UAT |
| Manual | Create draft twice | One linked line only | Automated/UAT |
| Manual | Delete draft | Payment returns to prior state | Automated/UAT |
| Manual | Post draft | Customer ledger entry linked; manually reconciled | Automated/UAT |
| Lifecycle | AUTHORISATION/PAR Authorised -> PAR SentForSettle -> PAR Settled | One merchant-qualified payment progresses Authorised -> SentForSettle -> Settled | Automated/UAT |
| Lifecycle | Authorised, SentForSettle, or Settled is the first retained event | Missing payment is backfilled through matching; Auto Post follows merchant configuration | Automated/UAT |
| Lifecycle | SentForSettle for an existing matching payment | Lifecycle milestone changes; no additional BC workflow or ledger action | Automated/UAT |
| Lifecycle | Capture failure/cancellation/expiry/completed, failed, or reversed refund/chargeback/chargeback reversal/second chargeback/settlement reversal | Mapped lifecycle plus Reversal Required; ledger/manual links retained; no auto reversal | Automated/UAT |
| Lifecycle | Cancelled/Expired PAR row or CANCELLATION/EXPIRE webhook after authorisation | Original merchant-qualified payment gets the final lifecycle and requires reversal review | Automated/UAT |
| Lifecycle | REFUND, CANCEL_OR_REFUND, TECHNICAL_CANCEL, or unsupported webhook intermediate | Event audited as intentionally ignored; no payment-state change | Automated/UAT |
| Lifecycle | SentForRefund, RefundAuthorised, or another unsupported PAR row | Row is excluded from normalized relevant events; no payment-state change | Automated/UAT |
| Lifecycle | Settled follows a later-dated SettledReversed | Lifecycle recovers to Settled while Reversal Required remains sticky | Automated/UAT |
| Lifecycle audit | New, repeated-state, adverse, recovery, stale, duplicate, failed, and unsupported events | Exact previous/resulting lifecycle and Changed, Applied without change, or Not applied effect is retained after successful processing | Automated |
| Lifecycle audit | Event processing fails and is retried successfully | Rolled-back attempt remains Unknown; successful retry records the exact outcome | Automated |
| Report URL | HTTP, custom port, deceptive host | Download rejected | Automated |
| Report HTTP | Mock success/failure/empty/oversize | Content loaded or deterministic error | Automated |
| Report file | Filename has zero or two `yyyy_MM_dd` dates | Load rejected | Automated |
| CSV | Reordered case-insensitive headers, extra fields, quoted comma | Parsed correctly | Automated |
| CSV | `Booking Date` with CET or CEST crosses a day/month/year boundary in UTC | Exact `Occurred At UTC` is retained using the supplied offset | Automated |
| CSV | Extra legacy `Booking Time` is present | Column is ignored; the combined `Booking Date` remains authoritative | Automated |
| CSV | Missing header, bad timestamp/time zone/amount, wrong merchant, partial load | Report never becomes Ready; a prepared report retains total/relevant counts with zero loaded rows and no partial events | Automated |
| Report identity | Same merchant/report ID or same file rows retried | Run/rows idempotent | Automated/UAT |
| Reconcile | Positive PAR milestone finds webhook payment | Lifecycle advances without overwriting source data | Automated/UAT |
| Reconcile | Positive PAR milestone has no payment | Backfilled through normal match/Auto Post path | Automated/UAT |
| Reconcile | Shopper/currency/amount difference | Data Conflict retained; authoritative data unchanged; Reversal Required has precedence | Automated |
| Report download | Short file, exact configured limit, one byte over limit, or empty response | Short and exact-limit files are retained; oversized and empty responses receive specific errors | Automated/UAT |
| Deadline | Two enabled merchants miss daily report | Separate overdue state; one alert per overdue period | Automated/UAT |
| Retry | Raw/event/report worker failure then correction, including retained or previously purged report content | Queueing does not delete retained content; a purged report can be downloaded again; corrected unit succeeds independently | Automated/UAT |
| Retention | Raw >90 days/report >13 months; new report has no date/content yet | Only eligible BLOB content is purged; pending downloads and metadata/events/payments/ledger links remain | Automated |
| Permissions | Service identity calls create API then attempts process/post | Create allowed; process/post denied | Tenant UAT |
| Role Center | Actionable, imported, posted, pending, active, terminal, draft, and overdue records exist | Every Adyen cue, including all imported payments and total/automatic/combined-manual/unclassified posted counts, includes only its intended records and drills down to the matching filtered list | Automated/UAT |
| Role Center history | User opens Webhook Requests or Event Entries from Monitor | Complete unfiltered history opens; pending and error cue drilldowns remain status-filtered | Tenant UAT |
| Audit | Drill down on PSP Reference or Adyen Lifecycle Status from any payment list | Dedicated lifecycle events open filtered by merchant and normalized payment PSP reference in newest-first order | Automated + tenant UAT |
| Page ordering | Open each operational list directly or through a filtered Role Center cue | Records open newest first while the page-specific status or posting filter remains intact | Automated + tenant UAT |
| Exception ordering | Open Payment Exceptions directly, through its cue or quick access, or with incoming merchant/status filters; creation, PK, and event-date orders conflict | Visible Created At UTC controls newest-first order, blank creation dates appear last, and exception plus incoming filters remain applied | Automated + tenant UAT |
| Audit | Open Source from webhook and report lifecycle events, before and after content retention | Exact source record opens; purged content metadata remains available while download stays unavailable | Automated + tenant UAT |
| Audit | Open Imported Events or drill down on External Report ID or Loaded Row Count from a report run | Event Entries opens filtered to events imported from the selected report run | Tenant UAT |
| Fresh install | Import a new authorisation and then a modification event | Creation time and normalized payment references are initialized immediately; later processing preserves creation time and earlier event outcomes | Automated |
| Audit | An event has not been processed or no payment lifecycle exists at that point | Lifecycle Effect remains Unknown until processing; absent before/after payment lifecycle values remain Unknown | Automated/UAT |
| CSV identity | Authoritative amount changes in value, sign, or decimal formatting; the unused amount column changes | Value/sign changes alter row identity; equivalent decimals and unused amount values do not; repeat loading remains idempotent | Automated |
| Posted Adyen payments | Automatic or manual Adyen journal posting has a retained customer ledger entry link | Role Center exposes the posting and origin; Posted By/At come from the customer entry; Open Posted Payment and Find Related Entries open the associated ledger records | Automated/UAT |
| Dashboard | Finance and administrator users select the Adyen Reconciliation profile | Adyen cues and quick-access tiles plus Accountant Activities, My Accounts, Adyen Job Queue Tasks, Report Inbox, and My Notes load without permission errors | Tenant UAT |
| Navigation | Finance and administrator users use the Role Center menus and workflow actions | All permitted Adyen, receivables, payables, cash-management, general-ledger, history, setup, creation, processing, and core-reporting destinations are reachable; restricted links are hidden | Tenant UAT |
| Job Queue navigation | Administrator opens Adyen Job Queue | Job Queue Entries opens filtered to Codeunit `72044`; a finance-only user without Job Queue read permission does not see the link | Tenant UAT |
| Job Queue cues | Adyen dispatcher entries are failed, in process, queued, on hold, finished, or unrelated | Only codeunit `72044` Error/In Process/Ready-or-Waiting entries populate their cues; any failed count is red and each drilldown preserves the dispatcher/status filters | Automated/UAT |
| Usability | Hover over cues, tiles, navigation and workflow actions, reports, Adyen controls, secret dialogs, and Payment Journal personalization | Each interactive extension control provides concise, accurate guidance | Tenant UAT |
| Flow | BC success/failure | `[accepted]` only after persistence; generic non-2xx otherwise | Tenant UAT |
| Shadow | Three days with Auto Post off | Counts, reports, backfills, matches, and exceptions approved by finance | Tenant UAT |
