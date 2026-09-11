# Testing and validation

## Build verification

Compile both apps against BC 28 symbols. The production package must be available in the package cache when compiling the test app. Generated `.app` files stay uncommitted.

The AL test app contains executable tests for:

- Adyen canonical escaping and HMAC vectors, malformed/changed signatures, hexadecimal keys, and previous-key rotation;
- two-, zero-, and three-decimal Adyen currency handling;
- multi-item intake, size/environment/merchant rejection, exact duplicate delivery, flow-run hash conflict, and normalization;
- merchant-qualified payment identities; the `Authorised -> SentForSettle -> Settled` progression; exact changed/applied-without-change/not-applied event outcomes; report-only backfill at each normal milestone; chronological, duplicate, recovery, data-conflict, cancelled/expired, refund, dispute, settlement-reversal, and retry rollback;
- merchant-qualified enabled/disabled/missing method policies with no cross-merchant fallback, missing/blocked customers, none/unique/multiple invoice matches, LCY normalization, foreign currency, partial amount, and overpayment;
- Auto Post off/on, exact posting and application, automatic/manual-exact/manual-journal origins, duplicate posting guard, preview and closed-period rollback, and manual-draft create/delete/post lifecycle using isolated test accounting data;
- mocked report HTTP success/failure, HTTPS/allowlist/port checks, file limits, filename dates, required authorised/captured amount and TimeZone columns, strict combined booking timestamps, CET/CEST-to-UTC boundary conversion, ignored legacy Booking Time fields, lifecycle-specific amount selection, case-insensitive reordered headers, quoting, durable row-count preparation, malformed/partial CSV rollback, authoritative signed-amount row identities, and idempotent row loading;
- per-merchant overdue state and content-only retention;
- fresh-record creation timestamps, normalized payment references, and preserved event outcomes; lifecycle source navigation to the exact webhook/report record before and after content purging;
- Role Center cue counts for payment exceptions, ready-to-post payments, all imported payments, total/automatic/combined-manual/unclassified posted payments with retained customer ledger links, manual journal drafts, pending and errored webhook requests, pending and errored events, active and errored report runs, enabled merchants with overdue reports, and failed/in-process/queued Adyen dispatcher entries. Unposted, terminal, and unrelated states are explicitly excluded.

The scenario index is [business-central/test/test-matrix.md](../business-central/test/test-matrix.md). The diagram and functional event matrix validated by these tests are in [payment lifecycle](payment-lifecycle.md).

## Tenant-only UAT

The following depend on a configured BC 28 tenant and cannot be proven by local AL compilation alone:

1. Power Automate connector discovery of the custom API and end-to-end Adyen retry/`[accepted]` behavior.
2. Real Adyen report Basic Auth, outbound HTTP approval, DNS/TLS certificate validation, and production host allowlisting.
3. Job Queue identity permissions, scheduling, time-zone behavior, per-unit rollback, retry state, and telemetry ingestion.
4. Posting/application into the tenant's actual journal templates, batches, clearing account, dimensions, number series, currencies, and posting groups.
5. Re-run posting/application, foreign-currency, closed-period rollback, duplicate guard, and manual-journal tests against the tenant's actual setup and permissions.
6. Manual customer override, re-evaluation, one linked draft, deletion reset, posting subscriber, and customer ledger link.
7. Three-day Auto Post-off shadow comparison for every merchant before production enablement.
8. Global and merchant-filtered payment-method policy page behavior, including new-row merchant inheritance.
9. **Adyen Reconciliation** profile selection and successful loading of the Adyen Activities, Adyen Quick Access, Accountant Activities, My Accounts, Adyen Job Queue Tasks, Report Inbox, and My Notes parts.
10. Every Adyen cue drills down with the intended filter; every Reconcile, Monitor, and Configure tile opens the intended page. Total Imported Payments includes every payment state. The posted total and Automatic, Manual, and Unclassified breakdowns include payments only when a posted customer ledger entry is linked; Manual combines exact-match and manual-journal origins.
11. Navigation reaches all eight top-level Adyen pages and the permitted Business Central receivables, payables, cash-management, general-ledger, history, setup, creation, processing, and core-reporting destinations.
12. Permission-aware navigation: finance-only users do not see Adyen configuration or Job Queue administration links; `ADYEN ADMIN` users can open Setup, Merchants, Payment Method Policies, and the dispatcher-filtered Job Queue when their standard Business Central permissions allow it.
13. The **Adyen Job Queue Tasks** card and filtered **Adyen Job Queue** destination contain only entries whose object type is Codeunit and object ID is `72044`. Failed counts are neutral at zero and red for any nonzero value; failed, in-process, and queued drilldowns preserve their exact status filters. Users without Job Queue Entry read permission do not see the card or link.
14. From **Posted Adyen Payments**, **Posting Origin** distinguishes the detailed route, **Posted By** and **Posted At** agree with the linked customer ledger entry, **Open Posted Payment** opens that entry, and **Find Related Entries** shows the G/L and detailed ledger entries sharing its document number and posting date.
15. New unposted payments have `Unclassified` posting origin; posting preview, a failed posting, and deleting an unposted manual draft do not set an origin.
16. Tooltip review across all cues, quick-access tiles, navigation and workflow actions, reports, Adyen page fields and actions, credential dialogs, and the Adyen Payment ID field available for Payment Journal personalization.
17. From Imported Payments, Payment Exceptions, and Posted Payments, both **PSP Reference** and **Adyen Lifecycle Status** open only the selected merchant-qualified payment's events in newest-first order.
18. From the lifecycle drilldown, **Open Source** opens the exact webhook request or report run. Repeat with retained content and with content marked as purged; metadata must remain reachable while the existing download action enforces retention.
19. From **Adyen Report Runs**, choose **Imported Events**, drill down on **External Report ID**, and drill down on **Loaded Row Count**. Confirm that each route opens an event list containing only events whose **Report Run Entry No.** belongs to the selected report run.
20. The Monitor **Webhook Requests** and **Event Entries** tiles open complete, unfiltered history, while the pending and error cues open only their corresponding statuses. In a clean, unpersonalized session, all operational lists open newest first: received time for webhook requests, occurrence time for events and lifecycle events, record creation time for imported payments and payment exceptions, request time for report runs, and posted customer-ledger entry number for posted payments. Confirm that **Created At UTC** is the first visible Imported Adyen Payments column and controls the order when opened directly, from Total Imported Payments, from Imported Adyen Payments quick access, and from the Ready-to-Post and Manual Journal Draft cues; the two filtered cues must keep their status filters. Repeat for **Adyen Payment Exceptions** opened directly, from its cue, quick access, and Role Center navigation: the creation column must be visible, newer-created payments must precede older payments even after an older payment receives a later lifecycle update, blank creation timestamps must appear last, and only exception statuses must appear.

## Acceptance evidence

For each UAT case retain the source payload/report hash, BC company and merchant, Job Queue entry/log, normalized event/payment/report IDs, match decision, ledger entry where applicable, expected result, actual result, tester, and timestamp. Never place secrets or raw customer payloads in general-purpose test logs.

Production readiness requires a clean production/test build, all automated AL tests passing in a BC 28 test runner, all tenant-only UAT rows passing, finance approval of the shadow run, and an exercised stop/recovery procedure.
