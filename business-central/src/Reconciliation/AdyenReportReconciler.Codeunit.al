codeunit 72034 "Adyen Report Reconciler"
{
    procedure ReconcileSentForSettle(InboxEntry: Record "Adyen Inbox Entry")
    var
        Payment: Record "Imported Adyen Payment";
        PaymentState: Codeunit "Adyen Payment State Mgt.";
        PaymentReference: Code[50];
    begin
        PaymentReference := PaymentState.GetOriginalPaymentReference(InboxEntry);
        if not Payment.Get(PaymentReference) then begin
            PaymentState.ImportPositivePayment(InboxEntry, true);
            Payment.Get(PaymentReference);
            Payment."Report Status" := Payment."Report Status"::Confirmed;
            Payment.Modify(true);
            exit;
        end;

        if (Payment.Status <> Payment.Status::ReversalRequired) and
           (Payment."Shopper Reference" = InboxEntry."Shopper Reference") and
           (Payment."Currency Code" = InboxEntry."Currency Code") and
           (Payment.Amount = InboxEntry.Amount)
        then begin
            Payment."Report Status" := Payment."Report Status"::Confirmed;
            Payment.Modify(true);
            exit;
        end;

        Payment."Report Status" := Payment."Report Status"::Discrepancy;
        Payment."Exception Message" := CopyStr(
            StrSubstNo('Report %1 differs from the imported payment customer, currency, amount, or lifecycle state.', InboxEntry."Report Run ID"),
            1, MaxStrLen(Payment."Exception Message"));
        Payment.Modify(true);
    end;
}
