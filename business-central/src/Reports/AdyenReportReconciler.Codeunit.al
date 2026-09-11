codeunit 72042 "Adyen Report Reconciler"
{
    procedure ReconcilePositiveLifecycleWithResult(EventEntry: Record "Adyen Event Entry"; var DispositionReason: Text[250]; var LifecycleApplied: Boolean)
    var
        Payment: Record "Imported Adyen Payment";
        PaymentState: Codeunit "Adyen Payment State";
        PaymentReference: Code[50];
    begin
        Clear(DispositionReason);
        LifecycleApplied := false;
        PaymentReference := PaymentState.GetOriginalPaymentReference(EventEntry);
        if not Payment.Get(EventEntry."Merchant Account", PaymentReference) then begin
            PaymentState.ImportPositivePaymentWithResult(EventEntry, true, DispositionReason, LifecycleApplied);
            exit;
        end;

        LifecycleApplied := PaymentState.ApplyLifecycleToPayment(Payment, EventEntry, DispositionReason);
        if not LifecycleApplied then
            exit;

        if not PaymentState.HasSameReportData(Payment, EventEntry) then
            PaymentState.MarkDataConflict(Payment, EventEntry);
        Payment.Modify(true);
    end;

}
