# Adyen Reconciliation for Business Central 28

Greenfield AL extension for Business Central Online 28 that validates and stores Adyen Standard webhooks, reconciles Payment Accounting Reports, matches customer invoices, and optionally posts and applies payments. Power Automate is only the public webhook relay. All validation, state, report processing, matching, and accounting run inside Business Central.

No Azure Functions, Service Bus, external storage, Key Vault, .NET service, or other Azure runtime component is used.

## Runtime flow

`Adyen -> Power Automate -> BC custom API -> raw webhook inbox -> Job Queue -> normalized events -> payments/reports -> match -> optional post/apply`

- Power Automate forwards the complete webhook envelope to the create-only API and returns `[accepted]` only after BC accepts it.
- BC checks the payload size, JSON envelope, test/live environment, merchant, and every item HMAC synchronously, then stores the raw request without doing accounting.
- A recurring Job Queue processes bounded transactional phases. Failed webhook/event units roll back and remain retryable; report preparation is retained separately so a failed atomic row load keeps its source content and diagnostic counts.
- Successful `AUTHORISATION` events create merchant-qualified payments. BC projects the newest supported Adyen lifecycle independently from its matching/posting workflow status. Adverse lifecycle events require finance review and never reverse entries automatically.
- `REPORT_AVAILABLE` events create merchant-qualified report runs. BC downloads and parses the CSV in the background, converts the official `Booking Date` plus `TimeZone` (`CET`/`CEST`) to UTC, tracks `Authorised -> SentForSettle -> Settled`, and backfills missing payments through the same matching path.
- Auto Post is off by default and is enabled separately for each merchant only after validation.

Production AL objects use `72000–72149`; AL test objects use `72150–72200`. The app keeps its original app ID and targets platform/application `28.0.0.0` with runtime `16.0`.

This codebase is a fresh-install baseline. It contains no upgrade routines or historical-data migrations. Payment lifecycle events, decision reasons, audit timestamps, source records, and posting links remain part of the supported data model. Report backfill for payments missed by webhooks remains a normal processing feature.

## Repository

- `business-central`: production AL app.
- `business-central-tests`: AL test app and report-download mock subscriber.
- `contracts`: Power Automate API schema and Adyen webhook/report fixtures.
- `docs`: architecture, setup, operations, Power Automate, and validation guidance.

Start with [setup](docs/setup.md), then build the [Power Automate flow](docs/power-automate.md). The canonical event-to-BC mapping is in [payment lifecycle](docs/payment-lifecycle.md), operational recovery is in [operations](docs/operations.md), and coverage/UAT is in [testing and validation](docs/testing-validation.md).

## Build

Download matching BC 28 symbols into `business-central/.alpackages`, then compile the production app and place that generated package in the symbol cache before compiling the tests:

```powershell
& $alc /project:'business-central' /packagecachepath:'business-central\.alpackages' /out:'business-central\.alpackages\Genesis Import GmbH_Adyen Reconciliation_1.0.0.13.app'
& $alc /project:'business-central-tests' /packagecachepath:'business-central\.alpackages' /out:'business-central-tests\Adyen-Reconciliation-Tests.app'
```

Generated `.app` packages, symbols, webhook payloads, report files, credentials, and `business-central/.vscode/rad.json` must not be committed.
