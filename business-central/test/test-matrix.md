# Business Central acceptance-test matrix

Automate these cases in the target tenant's standard AL test framework when its Test Toolkit dependency IDs are available.

| Area | Cases |
|---|---|
| Customer resolution | Exact customer, missing customer, blocked customer, finance override |
| Matching | One exact invoice, no match, two equal invoices, local and foreign currency, partial/overpayment |
| Idempotency | Same transport ID, newer retransmission, duplicate PSP reference, already-posted document number |
| Posting | Success, closed period, journal validation failure, full rollback, invoice application |
| Manual path | One draft only, missing customer blocked, deletion resets status, posting records ledger entry |
| Lifecycle | Failed authorisation ignored, late capture failure, refund, chargeback, older success after adverse event |
| Report | Loading is not processed, SentForSettle confirmation, backfill, discrepancy, duplicate report, incomplete rows |

