# Testing and validation

## Build verification

Compile both apps against BC 28 symbols. The production package must be available in the package cache when compiling the test app. Generated `.app` files stay uncommitted.

The AL test app contains executable tests for:

- Adyen canonical escaping and HMAC vectors, malformed/changed signatures, hexadecimal keys, and previous-key rotation;
- two-, zero-, and three-decimal Adyen currency handling;
- multi-item intake, size/environment/merchant rejection, exact duplicate delivery, flow-run hash conflict, and normalization;
- merchant-qualified payment identities, out-of-order authorisations, conflicting retransmissions, report backfill/discrepancy, and adverse lifecycle state;
- unsupported methods, missing/blocked customers, none/unique/multiple invoice matches, LCY normalization, foreign currency, partial amount, and overpayment;
- Auto Post off/on, exact posting and application, duplicate posting guard, closed-period rollback, and manual-draft create/delete/post lifecycle using isolated test accounting data;
- mocked report HTTP success/failure, HTTPS/allowlist/port checks, file limits, filename dates, case-insensitive reordered headers, quoting, malformed/partial CSV, and idempotent row loading;
- per-merchant overdue state and content-only retention.

The scenario index is [business-central/test/test-matrix.md](../business-central/test/test-matrix.md).

## Tenant-only UAT

The following depend on a configured BC 28 tenant and cannot be proven by local AL compilation alone:

1. Power Automate connector discovery of the custom API and end-to-end Adyen retry/`[accepted]` behavior.
2. Real Adyen report Basic Auth, outbound HTTP approval, DNS/TLS certificate validation, and production host allowlisting.
3. Job Queue identity permissions, scheduling, time-zone behavior, per-unit rollback, retry state, and telemetry ingestion.
4. Posting/application into the tenant's actual journal templates, batches, clearing account, dimensions, number series, currencies, and posting groups.
5. Re-run posting/application, foreign-currency, closed-period rollback, duplicate guard, and manual-journal tests against the tenant's actual setup and permissions.
6. Manual customer override, re-evaluation, one linked draft, deletion reset, posting subscriber, and customer ledger link.
7. Three-day Auto Post-off shadow comparison for every merchant before production enablement.

## Acceptance evidence

For each UAT case retain the source payload/report hash, BC company and merchant, Job Queue entry/log, normalized event/payment/report IDs, match decision, ledger entry where applicable, expected result, actual result, tester, and timestamp. Never place secrets or raw customer payloads in general-purpose test logs.

Production readiness requires a clean production/test build, all automated AL tests passing in a BC 28 test runner, all tenant-only UAT rows passing, finance approval of the shadow run, and an exercised stop/recovery procedure.
