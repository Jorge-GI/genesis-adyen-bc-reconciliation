codeunit 72042 "Adyen Report Reconciler"
{
    procedure ReconcileSentForSettle(EventEntry: Record "Adyen Event Entry")
    var
        Payment: Record "Imported Adyen Payment";
        PaymentState: Codeunit "Adyen Payment State";
        PaymentReference: Code[50];
    begin
        PaymentReference := PaymentState.GetOriginalPaymentReference(EventEntry);
        if not Payment.Get(EventEntry."Merchant Account", PaymentReference) then begin
            PaymentState.ImportPositivePayment(EventEntry, true);
            Payment.Get(EventEntry."Merchant Account", PaymentReference);
            Payment."Report Status" := Payment."Report Status"::Confirmed;
            Payment.Modify(true);
            exit;
        end;

        if (Payment.Status <> Payment.Status::ReversalRequired) and
           (Payment."Shopper Reference" = EventEntry."Shopper Reference") and
           (Payment."Currency Code" = EventEntry."Currency Code") and
           (Payment.Amount = EventEntry.Amount)
        then begin
            Payment."Report Status" := Payment."Report Status"::Confirmed;
            Payment.Modify(true);
            exit;
        end;

        Payment."Report Status" := Payment."Report Status"::Discrepancy;
        Payment."Exception Message" := CopyStr(
            StrSubstNo('Report row %1 differs from the imported payment customer, currency, amount, or lifecycle state.', EventEntry."Report Row No."),
            1, MaxStrLen(Payment."Exception Message"));
        Payment.Modify(true);
    end;
}
