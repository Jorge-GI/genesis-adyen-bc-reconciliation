# Business Central acceptance-test matrix

Automate these cases in the target tenant's standard AL test framework when its Test Toolkit dependency IDs are available.

The executable end-to-end procedures, evidence requirements, pass criteria, and sign-off record are maintained in the
[testing and validation guide](../../docs/testing-validation.md). This file remains the backlog for future AL test automation
and must not be treated as release approval by itself.

| Area | Cases |
|---|---|
| Customer resolution | Exact customer, missing customer, blocked customer, finance override |
| Matching | One exact invoice, no match, two equal invoices, local and foreign currency, partial/overpayment |
| Idempotency | Same transport ID, newer retransmission, duplicate PSP reference, already-posted document number |
| Posting | Success, closed period, journal validation failure, full rollback, invoice application |
| Manual path | One draft only, missing customer blocked, deletion resets status, posting records ledger entry |
| Lifecycle | Failed authorisation ignored, late capture failure, refund, chargeback, older success after adverse event |
| Report | Loading is not processed, SentForSettle confirmation, backfill, discrepancy, duplicate report, incomplete rows |

