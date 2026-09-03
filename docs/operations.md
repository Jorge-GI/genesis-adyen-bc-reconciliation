# Operations and recovery

## Daily checks

- Service Bus dead-letter counts must be zero.
- The newest Adyen Report Run must become `Processed` after it becomes `Ready`.
- Review Imported Payments with `Report Status = Discrepancy`.
- Review payment statuses `Imported`, `Error`, and `Reversal Required`.
- Treat the Adyen setup `Report Overdue` flag and `ADYEN001` telemetry event as operational alerts.

## Retry boundaries

- Azure transient failures: allow Service Bus to retry. Investigate and replay the dead-letter message only after correcting the cause.
- Business Central processing errors: open Adyen Inbox Entries, correct configuration or accounting data, then use **Retry**.
- Do not edit immutable inbound fields or archive hashes.
- Duplicate replay is safe only when the transport/report ID and payload/file hash agree.

## Manual payment handling

1. Resolve a valid customer on the Imported Adyen Payment.
2. Select **Create Manual Journal Line**. The action creates at most one linked draft.
3. Use standard Business Central Apply Entries and posting. The extension records the posted customer-ledger entry through the immutable Adyen Payment ID.
4. If the draft is deleted before posting, the imported payment returns to its prior exception status.

## Adverse events

A capture failure, successful refund, or chargeback marks the payment `Reversal Required`, even when it was already applied. V1 intentionally does not unapply or reverse accounting entries. Finance must investigate and perform any corrective posting under normal approval controls.

## Key rotation

Add the new HMAC key as current and keep the former value as previous until Adyen propagation and retries are complete. Rotate the Adyen OAuth client credential, report credential, and Business Central client credential through Key Vault without putting values in application settings or source control.
