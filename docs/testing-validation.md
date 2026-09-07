# Testing and validation guide

Use this document to validate the complete Adyen-to-Business Central reconciliation solution in an Adyen test merchant and a Business Central sandbox. Do not execute destructive, security-negative, or fault-injection tests in production.

This validation certifies the current v1 behavior. In particular:

- A payment matches any uniquely qualifying open customer-ledger invoice; the extension does not distinguish a normal invoice from a posted prepayment invoice.
- Posting the payment does not release or modify a sales order.
- `Merchant Reference` is retained but is not used by the invoice matcher.
- Refunds, chargebacks, capture failures, and settlement reversals require finance review; they are not reversed automatically.
- Business Central tables and standard ledger entries are authoritative evidence where no explicit telemetry event exists.

## 1. Validation record

Complete this header before testing. Do not record credentials or raw customer/payment data.

| Field | Value |
|---|---|
| Validation cycle/reference |  |
| Test start and end dates |  |
| Adyen test merchant |  |
| Azure subscription/resource group |  |
| Business Central tenant/environment/company |  |
| Extension app ID | `8d42ce86-f04f-4c45-bec4-315451f469d4` |
| Extension version |  |
| Extension package SHA-256 |  |
| Source commit |  |
| Ingress Function version/deployment ID |  |
| Worker Function version/deployment ID |  |
| Test lead |  |
| Finance approver |  |
| Integration approver |  |
| Security approver |  |
| Operations approver |  |

## 2. Entry criteria

All conditions must be true before executing functional tests:

- [ ] The test installation was completed using [setup.md](setup.md).
- [ ] `.NET` restore, Release build, and automated tests passed for the source commit under test.
- [ ] The production AL extension compiled against matching Business Central 28 symbols.
- [ ] The extension package and both Function deployments correspond to the recorded source commit.
- [ ] Test and production use different Adyen merchants, Azure resources, Entra credentials, HMAC keys, and BC environments.
- [ ] Required Key Vault references are healthy without exposing secret values.
- [ ] The extension is installed and its pages are available in the sandbox company.
- [ ] The worker Entra application has only `ADYEN SERVICE` in Business Central.
- [ ] Test users and the Job Queue identity have the agreed extension and standard posting permissions.
- [ ] A dedicated journal template, automatic batch, manual batch, and clearing G/L account are configured.
- [ ] The Job Queue runs every minute under a user with the `Europe/Berlin` time zone.
- [ ] `Auto Post` is off for baseline UAT and shadow validation.
- [ ] Test payment methods exist in **Adyen Payment Method Policies**; only methods used in controlled tests are enabled.
- [ ] The Adyen Payment Accounting Report contains every required column listed in [setup.md](setup.md#93-daily-payment-accounting-report).
- [ ] Application Insights access, Blob archive read access, Business Central page access, and ledger inquiry access are available to the test lead.
- [ ] Test data can be deleted or reversed under the sandbox's normal accounting controls after evidence is approved.

## 3. Test data

Create isolated data in the sandbox. Replace the sample identifiers with values approved for the test company.

| Data ID | Required setup |
|---|---|
| `CUST-VALID` | Unblocked customer whose number is at most 20 characters and is sent as `shopperReference` |
| `CUST-BLOCKED` | Blocked customer |
| `METHOD-VALID` | Adyen test method present and enabled in Payment Method Policies |
| `METHOD-DISABLED` | Method absent from policies or present but disabled |
| `INV-EXACT` | One open normal invoice for `CUST-VALID`, EUR 100.00 |
| `INV-NOMATCH` | Open invoice whose amount differs from the test payment |
| `INV-MULTI-A/B` | Two open invoices for the same customer, currency, and EUR 75.00 remaining amount |
| `PREPAY-ONLY` | One open posted sales prepayment invoice, EUR 60.00, with no other equal invoice |
| `PREPAY-MULTI` | One open prepayment invoice and one normal invoice, both EUR 65.00 |
| `INV-USD` | One open USD invoice used for currency-mismatch testing |
| `ORDER-PREPAY` | Sales order associated with `PREPAY-ONLY`; record its status before testing |
| `CLEARING` | Configured Adyen clearing G/L account with a zero or recorded opening balance |

Use a different real Adyen test PSP reference for every scenario unless the scenario explicitly validates replay or duplicate handling. Test data injected directly into a custom API must use the versioned contracts under `contracts`; do not manually edit immutable Business Central inbox identifiers or hashes.

## 4. Evidence standard

### 4.1 Evidence package

Create one folder per test case using `TV-<TEST-ID>-<YYYYMMDD>`. Store only sanitized exports, screenshots, hashes, and query results. Each case must include:

1. Test data identifiers and the PSP reference.
2. Execution timestamp and tester.
3. Expected and actual result.
4. Relevant correlation identifiers.
5. Evidence filenames or approved evidence-system links.
6. Pass, fail, blocked, or not-applicable result.
7. Defect/waiver reference when the result is not Pass.

Use this template for every case:

```markdown
### <TEST-ID> — <title>

- Priority: Critical | High | Medium
- Tester/date:
- Preconditions and test data:
- Steps performed:
- Expected result:
- Actual result:
- PSP reference:
- Transport ID / logical event key:
- BC invoice and payment entry numbers:
- Report ID / row identity:
- Evidence:
- Result: Pass | Fail | Blocked | N/A
- Defect or approved waiver:
```

### 4.2 End-to-end trace chain

For every positive payment, demonstrate this chain:

```text
Adyen PSP reference
  -> BC Inbox PSP/Original PSP Reference
  -> Inbox Transport ID + Logical Event Key + Payload Hash
  -> Azure worker trace by Transport ID
  -> Raw Blob URL + matching sha256 metadata
  -> Imported Adyen Payment by original PSP reference
  -> Matched Invoice Entry No.
  -> Posted Payment Entry No. and standard BC ledger entries
  -> SentForSettle report inbox row
  -> Report Row Identity + Report Run ID
  -> Adyen Report Run file hash, row counts, and Processed status
```

Capture these Business Central fields:

| Page | Required fields |
|---|---|
| Adyen Inbox Entries | Source, message type, PSP references, Transport ID, Logical Event Key, Payload Hash, received/processed time, status, retry count, last error, report identifiers, archive reference |
| Imported Adyen Payments | PSP reference, source, customer, amount/currency, latest event key/time, match result, status, matched invoice entry, posted payment entry, report status, backfilled flag, exception |
| Adyen Report Runs | Report ID/date, file hash, total/relevant/loaded counts, status, error, archive reference, started/ready/processed times |
| Customer Ledger Entries | Invoice entry, payment entry, document numbers, amount/remaining amount, open state, transaction number |
| G/L Entries | Transaction/document number, customer-control/clearing postings, amount, currency and dimensions required by finance |

### 4.3 Azure Application Insights queries

The Bicep template retains the Log Analytics data for 30 days. Export evidence before that period expires.

Search a webhook by the Business Central inbox Transport ID:

```kusto
let transportId = "REPLACE_WITH_TRANSPORT_ID";
traces
| where timestamp > ago(30d)
| where message has transportId or tostring(customDimensions) has transportId
| project timestamp, severityLevel, message, operation_Id, customDimensions
| order by timestamp asc
```

The explicit successful-worker message is:

```text
Processed Adyen webhook transport {TransportId}.
```

Search a report by Report Run ID:

```kusto
let reportId = "REPLACE_WITH_REPORT_ID";
traces
| where timestamp > ago(30d)
| where message has reportId or tostring(customDimensions) has reportId
| project timestamp, severityLevel, message, operation_Id, customDimensions
| order by timestamp asc
```

The explicit successful-report message is:

```text
Loaded report {ReportId} with {RelevantRows} relevant row(s).
```

Search Function exceptions around a test window:

```kusto
exceptions
| where timestamp between (datetime(YYYY-MM-DDTHH:MM:SSZ) .. datetime(YYYY-MM-DDTHH:MM:SSZ))
| project timestamp, type, outerMessage, operation_Id, customDimensions
| order by timestamp asc
```

The ingress also logs accepted item counts and rejection reasons, but its successful acceptance message does not contain a PSP reference or Transport ID. Treat it as service-level evidence, not payment-level correlation.

### 4.4 Business Central telemetry limitation

The only explicit custom AL telemetry call is the overdue-report event `ADYEN001`. The extension manifest does not currently configure an extension-publisher Application Insights connection, so the event is conditional evidence. If the deployment process supplies that connection, query it with:

```kusto
traces
| where timestamp > ago(30d)
| where tostring(customDimensions.eventId) endswith "ADYEN001"
| project timestamp, message, severityLevel, companyName=customDimensions.Company,
          category=customDimensions.Category, customDimensions
| order by timestamp asc
```

Whether or not telemetry is connected, `Adyen Setup.Report Overdue` and `Report Alert Message` are mandatory evidence. There are no explicit AL log events for inbox success, payment import, match result, posting, application, report-row confirmation, manual reconciliation, or adverse-event handling.

## 5. Installation, access, and security tests

| ID | Pri. | Scenario and procedure | Expected result | Required evidence |
|---|---|---|---|---|
| `INST-01` | Critical | Verify the recorded `.app` is installed in the sandbox company. Search all six extension pages. | Version and app ID match the validation record; every page opens. | Manage Apps/App Management record and page screenshots |
| `INST-02` | Critical | Authenticate as the worker service application with the client-credential flow and call the versioned inbound API with a valid sanitized message. | API accepts the record; no interactive or posting privileges are available. | Entra application record, assigned `ADYEN SERVICE`, API response, inbox row |
| `INST-03` | High | Test an admin, finance user, unauthorized user, and Job Queue identity. | Admin can configure; finance can review/post; unauthorized user cannot access extension data; Job Queue can process/post as configured. | Permission assignments and outcome per identity |
| `INST-04` | Critical | Create/review the Adyen Inbox Dispatcher Job Queue entry. | Recurring one-minute entry exists, uses the approved identity/time zone, and completes a run. | Job Queue Entry and Job Queue Log Entry |
| `INST-05` | High | Verify the journal template, two separate batches, clearing account, merchant, environment, report deadline, and retention display values. | Values match the approved worksheet; `Auto Post` is off. | Sanitized Adyen Setup and journal setup |
| `SEC-01` | Critical | Send a valid OAuth- and HMAC-protected Adyen test webhook. | Ingress returns `202`; the item reaches the webhook queue and then BC inbox. | Adyen webhook test, Function trace, inbox row |
| `SEC-02` | Critical | Send the same shape without an OAuth token. | App Service Authentication returns `401`; no queue or inbox record is created. | HTTP result, ingress request telemetry, zero downstream records |
| `SEC-03` | Critical | Send an authenticated payload with an invalid HMAC. | Ingress returns `401` with a generic authentication error; no downstream record is created. | HTTP result and rejection trace without secret data |
| `SEC-04` | Critical | Send authenticated/HMAC-valid data for the wrong merchant and, separately, the wrong test/live environment. | Both are rejected; no queue or inbox record is created. | Rejection traces and zero downstream records |
| `SEC-05` | High | Review deployed triggers, identities, RBAC, and network endpoints. | Worker has no HTTP trigger; ingress cannot read worker vault/archive; worker has only required queue, vault, archive, and BC access. | Function list and Azure role-assignment export |

## 6. Payment import and matching tests

Keep `Auto Post` off throughout this section.

| ID | Pri. | Scenario and procedure | Expected result | Required evidence |
|---|---|---|---|---|
| `PAY-01` | Critical | Create a successful immediately captured EUR 100.00 Adyen test payment for `CUST-VALID` while `INV-EXACT` is the only matching invoice. | Webhook inbox row becomes `Processed`; imported payment is `Ready to post`, `Unique exact`, and points to `INV-EXACT`; no ledger payment exists yet. | Complete trace through imported payment and proof of no payment entry |
| `PAY-02` | High | Submit an `AUTHORISATION` with `success=false`. | Inbox becomes `Processed`; no positive imported payment is created. | Inbox event and absence of payment aggregate |
| `MATCH-01` | Critical | Use an unknown `shopperReference`. | Payment stays `Imported`; match is `Invalid customer`; exception explains resolution failure. | Inbox and imported-payment fields |
| `MATCH-02` | High | Use `CUST-BLOCKED`. | Payment stays `Imported`; match is `Invalid customer`; exception states the customer is blocked. | Customer block status and payment exception |
| `MATCH-03` | High | Use `METHOD-DISABLED`. | Payment stays `Imported`; match is `Unsupported payment method`; nothing posts. | Policy record and payment exception |
| `MATCH-04` | Critical | Send a payment for which no open invoice has the same currency and exact remaining amount. | Payment stays `Imported`; match is `No match`. | Customer ledger candidates and exception |
| `MATCH-05` | Critical | Send EUR 75.00 when `INV-MULTI-A/B` are both open. | Payment stays `Imported`; match is `Multiple`; no invoice entry is selected. | Both invoices and payment match result |
| `MATCH-06` | High | Send EUR for `INV-USD`, then test a matching USD payment. | EUR case is `No match`; USD case can be `Unique exact` when it is the sole USD candidate. | Currency/remaining amounts and both results |
| `MATCH-07` | High | Send a partial amount and then an amount greater than the invoice remaining amount. | Both remain `Imported` with `No match`; no posting occurs. | Payment/invoice amounts and no payment entries |
| `MATCH-08` | High | Change `Resolved Customer No.` to an approved valid customer and choose **Re-evaluate Match**. | Matcher uses the override; result reflects that customer's open invoices. | Before/after customer and match fields |
| `MATCH-09` | High | Provide a `shopperReference` longer than 20 characters without a finance override. | It is not copied into the customer-number field; automatic resolution fails. | Inbox shopper reference and payment result |
| `MATCH-10` | High | Use a merchant reference equal to an invoice/order number while customer, currency, or amount does not qualify. | Merchant reference does not force a match. | Merchant reference, candidates, match result |

## 7. Invoice and sales-order behavior

| ID | Pri. | Scenario and procedure | Expected result | Required evidence |
|---|---|---|---|---|
| `INV-01` | Critical | Make a normal posted invoice the sole qualifying entry and re-evaluate. | Normal invoice is selected as `Unique exact`. | Matched invoice entry and source document |
| `INV-02` | Critical | Make `PREPAY-ONLY` the sole qualifying entry and re-evaluate. | Posted prepayment invoice is selected because it is an open customer-ledger `Invoice`; v1 does not distinguish its origin. | Prepayment invoice, ledger entry, match result |
| `INV-03` | Critical | Open `PREPAY-MULTI` and an equal normal invoice for the same customer/currency. | Match is `Multiple`; neither is selected or posted automatically. | Both ledger entries and payment result |
| `INV-04` | Critical | Record the status of `ORDER-PREPAY`, post/apply the matching payment to `PREPAY-ONLY`, and reopen the order. | Payment closes the prepayment invoice; the sales-order status and release state are unchanged. | Before/after order status, invoice, payment and application entries |

`INV-02` and `INV-04` validate accepted v1 behavior, not a guarantee that payments always target prepayment invoices or release orders.

## 8. Posting and accounting tests

| ID | Pri. | Scenario and procedure | Expected result | Required evidence |
|---|---|---|---|---|
| `POST-01` | Critical | With `Auto Post` off, process a unique exact payment and wait for Job Queue completion. | Status is `Ready to post`; no customer or G/L payment entry is created. | Setup, imported payment, Customer/G/L Entry searches |
| `POST-02` | Critical | On the `PAY-01` record choose **Post Exact Match**. | A customer payment is posted with PSP reference as document/external document number, negative absolute amount, and clearing G/L balance; invoice remaining amount is zero; status is `Posted and applied`. | Imported payment, customer payment, detailed application, invoice, balanced G/L entries |
| `POST-03` | Critical | Prepare a unique exact payment whose event/posting date is outside the test user's allowed posting period and choose **Post Exact Match**. | Posting fails; no partial customer/G/L/application entries remain; payment is not `Posted and applied`. | Error, before/after ledger searches, payment state |
| `POST-04` | Critical | Under controlled sandbox setup, create an existing customer payment with the new test PSP reference as document number, then attempt extension posting. | Extension rejects the duplicate; it does not create a second payment. | Existing entry, duplicate error, count after attempt |
| `POST-05` | Critical | Reconcile the posted payment transaction. | Customer credit and clearing-account debit/credit treatment balance to zero by transaction; currency and dimensions follow approved setup. | Customer, detailed customer, and G/L entries signed by finance |
| `POST-06` | High | Choose **Post Exact Match** again on an already linked posted payment. | No second payment is created. | Before/after counts and stored payment entry number |

## 9. Manual handling tests

| ID | Pri. | Scenario and procedure | Expected result | Required evidence |
|---|---|---|---|---|
| `MAN-01` | High | Resolve a valid customer on a no-match exception and choose **Create Manual Journal Line**. | One draft appears in the configured manual batch with customer, currency, negative amount, PSP document numbers, clearing account, and Adyen Payment ID. | Imported payment and journal line |
| `MAN-02` | High | Choose **Create Manual Journal Line** again without deleting/posting the first draft. | The existing draft opens; no duplicate line is created. | Journal line count and stored template/batch/line number |
| `MAN-03` | High | Delete the unposted linked draft. | Payment returns to its prior status; manual template/batch/line fields are cleared. | Before/after payment and journal |
| `MAN-04` | Critical | Recreate the draft, use standard **Apply Entries**, and post it. | Posted customer-ledger entry is stored; payment becomes `Manually reconciled`; exception is cleared. | Journal posting result, application, payment status and entry number |

## 10. Idempotency and ordering tests

Use only sanitized contract payloads and an approved API/replay harness.

| ID | Pri. | Scenario and procedure | Expected result | Required evidence |
|---|---|---|---|---|
| `IDEM-01` | Critical | Submit the same Transport ID and payload hash twice. | Second submission is an idempotent success; one inbox record exists. | Two API/worker outcomes and one BC row |
| `IDEM-02` | Critical | Reuse a Transport ID with a different payload hash. | BC rejects the request; original row remains unchanged. | Rejection and before/after row |
| `IDEM-03` | High | Send a legitimate retransmission with a different received/event timestamp but the same logical event identity. | Distinct transport is retained; logical key groups the events; one payment aggregate exists. | Both inbox rows and one payment |
| `IDEM-04` | Critical | After a newer positive event updates a payment, submit an older positive event with different non-key details. | Older event does not replace the payment's newer aggregate state. | Ordered inbox rows and unchanged latest payment fields |
| `IDEM-05` | Critical | After a payment is `Reversal required`, replay an older successful authorisation. | Adverse state is not cleared automatically. | Adverse/older inbox events and payment status |

## 11. Report reconciliation tests

| ID | Pri. | Scenario and procedure | Expected result | Required evidence |
|---|---|---|---|---|
| `RPT-01` | Critical | Process a valid daily Payment Accounting Report and observe the run. | Run progresses `Loading -> Ready -> Processed`; total, relevant, and loaded counts agree; every relevant inbox row finishes. | Report run at each stage, row counts, worker trace |
| `RPT-02` | Critical | Include the `PAY-01` PSP reference as a matching `SentForSettle` row. | Existing payment becomes `Report Status = Confirmed`; source values are not overwritten. | Report row, payment before/after, report run |
| `RPT-03` | Critical | Include a valid `SentForSettle` row for which no webhook payment exists. | Payment is created from the report, `Backfilled = true`, and `Report Status = Confirmed`; matching/posting follows normal policy. | Absence before, report row, backfilled payment |
| `RPT-04` | Critical | Provide a row whose customer, currency, or amount differs from an existing payment, and separately test a payment already requiring reversal. | `Report Status = Discrepancy`; exception identifies the report; source payment values are not overwritten. | Before/after payment and report row |
| `RPT-05` | Critical | Attempt to set a report `Ready` when relevant and loaded row counts differ. | BC rejects the state change; run is not Ready. | API error and report run |
| `RPT-06` | High | Replay the same Report ID and file hash. | Existing report is accepted idempotently; report/rows are not duplicated. | Replay result and record counts |
| `RPT-07` | Critical | Reuse a Report ID with a different file hash. | BC rejects the report; original hash and run remain unchanged. | Error and original report run |
| `RPT-08` | High | Supply a report filename with no date and then one with a multi-day range. | Worker rejects each as `InvalidReport`; message is dead-lettered and no Ready run is produced. | DLQ reason/description, Function evidence, report run if created |
| `RPT-09` | Critical | After the configured deadline, arrange for the previous day's report to be absent, then restore it. | `Report Overdue` and alert message are set, then clear after the ready-date condition is satisfied; `ADYEN001` is evidence only when publisher telemetry is configured. | Setup before/after and conditional telemetry |

## 12. Adverse-event tests

| ID | Pri. | Scenario and procedure | Expected result | Required evidence |
|---|---|---|---|---|
| `ADV-01` | Critical | Send `CAPTURE_FAILED` for an imported or posted payment. | Payment becomes `Reversal required`; finance-review exception is stored; no automatic unapplication/reversal occurs. | Inbox, payment, unchanged ledger/application |
| `ADV-02` | Critical | Send a successful refund event. | Payment becomes `Reversal required`; no automatic refund posting occurs. | Inbox, payment and unchanged/new-entry searches |
| `ADV-03` | Critical | Send a successful chargeback and separately a second chargeback. | Each related payment becomes/remains `Reversal required`; no automatic correction is posted. | Inbox events, payment and ledger |
| `ADV-04` | Critical | Process a settlement-reversed event. | Payment becomes `Reversal required`; finance must correct it manually. | Inbox, payment and ledger |
| `ADV-05` | High | Send a refund/adverse notification with `success=false` other than capture failure. | Event is processed but does not mark the payment for reversal. | Inbox and unchanged payment status |

## 13. Recovery and archive tests

| ID | Pri. | Scenario and procedure | Expected result | Required evidence |
|---|---|---|---|---|
| `REC-01` | High | Temporarily disable the BC worker service application in the sandbox, send one test webhook, observe at least one retry, then re-enable it before delivery count 10. | Service Bus retains/retries the message; it ultimately reaches BC once and is completed. | Delivery/invocation evidence and one inbox row |
| `REC-02` | Critical | During the controlled sandbox activation stage, cause automatic posting to fail using a closed posting date. Return `Auto Post` to off, correct the date, choose **Retry** on the Error inbox row, and let the Job Queue run. | First run stores `Status = Error`, increments retry count, and stores Last Error; retry clears Last Error and reaches `Processed` without duplicate accounting. Payment becomes `Ready to post` because Auto Post is off again. | Inbox before/after, setup changes, payment and ledger counts |
| `REC-03` | Critical | Compare an inbox Payload Hash with the raw webhook blob filename and `sha256` metadata. Repeat for a report file hash/archive. | Hashes agree and archive URLs are private; original content can be retrieved only by authorized operators. | Hash comparison and access-control evidence |
| `REC-04` | High | Send malformed queue/report content using the approved harness. | Defined dead-letter reason and sanitized description are present; no partial financial posting exists. | DLQ metadata, Function evidence, BC/ledger absence |

Do not leave the service application disabled long enough to reach `maxDeliveryCount = 10`. Do not change queue delivery settings for UAT.

## 14. Controlled sandbox activation

Complete baseline UAT first. `Auto Post` remains off during the functional baseline and all three shadow-report cycles. After the baseline receives provisional finance approval:

1. Confirm only `METHOD-VALID` is enabled and create exactly one safe, uniquely matching test invoice.
2. Obtain finance and test-lead approval for the activation window.
3. Turn `Auto Post` on in the sandbox.
4. Execute `REC-02`, return `Auto Post` to off, correct the fault, and complete the retry.
5. Turn `Auto Post` on again and send one safe payment with an open posting date.
6. Confirm the Job Queue posts and applies it without user action, and capture the same accounting evidence required by `POST-02` and `POST-05`.
7. Turn `Auto Post` off immediately after evidence is captured.
8. Confirm no unapproved payment methods or unrelated imported payments were posted during either window.

This activation validates the automatic invocation of the already-tested posting code; it does not authorize production Auto Post.

## 15. Three-day shadow validation

Run three consecutive daily report cycles with `Auto Post` off. Complete one row per cycle.

| Check | Day 1 | Day 2 | Day 3 |
|---|---|---|---|
| Date/report ID |  |  |  |
| Successful authorisations counted |  |  |  |
| Imported/ready payments counted |  |  |  |
| `SentForSettle` relevant rows counted |  |  |  |
| Backfills explained |  |  |  |
| Discrepancies explained |  |  |  |
| Inbox errors/retries explained |  |  |  |
| Report reached `Processed` |  |  |  |
| Webhook/report DLQ counts are zero |  |  |  |
| No automatic customer payment posted |  |  |  |
| Operations initials |  |  |  |
| Finance initials |  |  |  |

Reset the three-day count after an unexplained missing payment, discrepancy, dead-letter message, duplicate posting, unbalanced accounting entry, or report that fails to reach `Processed`.

## 16. Defect severity and exit criteria

### 16.1 Severity

| Severity | Definition | Release effect |
|---|---|---|
| 1 — Critical | Security boundary failure, lost/duplicated payment, wrong customer/invoice, unbalanced posting, unauthorized automatic posting, unrecoverable corruption | Stop testing and block release |
| 2 — High | Required integration/report/recovery path fails or trace evidence cannot establish financial completeness | Block release |
| 3 — Medium | Operable defect with an approved workaround and no financial/security impact | Requires documented owner, target date, and approval |
| 4 — Low | Documentation, usability, or cosmetic issue | May be accepted into backlog |

### 16.2 Exit criteria

All of these conditions are mandatory:

- [ ] Every Critical test passes.
- [ ] Every High test passes or is explicitly marked N/A because its precondition cannot occur, with approval from the test lead and relevant domain owner.
- [ ] No open Severity 1 or Severity 2 defect exists.
- [ ] Customer, application, and clearing-account entries balance and were approved by finance.
- [ ] No duplicate customer payment or incorrect invoice application occurred.
- [ ] Every positive payment selected for evidence has a complete trace chain.
- [ ] Report confirmation, backfill, discrepancy, and adverse-event behavior match v1.
- [ ] The accepted prepayment-invoice and no-sales-order-release behaviors are signed off.
- [ ] The controlled sandbox Auto Post activation passed and Auto Post was returned to off.
- [ ] Three consecutive shadow-report cycles passed.
- [ ] Production deployment worksheet, rollback procedure, support ownership, and monitoring access are approved.

## 17. Sign-off

| Domain | Name | Decision | Date | Signature/reference | Conditions |
|---|---|---|---|---|---|
| Finance/accounting |  | Approve / Reject |  |  |  |
| Business Central |  | Approve / Reject |  |  |  |
| Azure/integration |  | Approve / Reject |  |  |  |
| Security |  | Approve / Reject |  |  |  |
| Operations/support |  | Approve / Reject |  |  |  |
| Business owner |  | Approve / Reject |  |  |  |

Approval authorizes a controlled production deployment and smoke test. It does not by itself authorize production `Auto Post`; record that approval separately after the production smoke evidence is reviewed.

## 18. Production smoke validation

After production installation, with `Auto Post` off:

1. Verify extension version, permissions, setup, Key Vault references, Function versions, queues, and Job Queue configuration against the production worksheet.
2. Execute one finance-approved controlled payment using an approved method and uniquely matching invoice.
3. Confirm ingress acceptance, worker completion, BC inbox processing, unique match, and absence of automatic posting.
4. Post through **Post Exact Match** only with finance approval and verify the customer, application, and clearing entries.
5. Confirm the corresponding daily report row changes the payment to `Confirmed` and the report reaches `Processed`.
6. Confirm DLQ counts, inbox errors, discrepancies, and overdue status are clear.
7. Obtain explicit finance and operations approval before turning production `Auto Post` on.

If any smoke step fails, keep `Auto Post` off, put the Job Queue on hold, preserve all evidence, and follow the safe-stop procedure in [setup.md](setup.md#12-safe-stop-and-rollback).
