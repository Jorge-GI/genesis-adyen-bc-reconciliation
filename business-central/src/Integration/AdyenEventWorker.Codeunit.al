codeunit 72050 "Adyen Event Worker"
{
    TableNo = "Adyen Event Entry";

    trigger OnRun()
    var
        PaymentBefore: Record "Imported Adyen Payment";
        ReportRun: Record "Adyen Report Run";
        PaymentState: Codeunit "Adyen Payment State";
        EventDisposition: Codeunit "Adyen Event Disposition";
        ReportManagement: Codeunit "Adyen Report Management";
        ReportReconciler: Codeunit "Adyen Report Reconciler";
        PreviousLifecycleStatus: Enum "Adyen Lifecycle Status";
        DispositionReason: Text[250];
        MessageType: Text;
        PaymentReference: Code[50];
        LifecycleApplied: Boolean;
        PaymentExistedBefore: Boolean;
    begin
        ClearLifecycleOutcome(Rec);
        EventDisposition.ClearReason(Rec);
        PaymentReference := PaymentState.GetOriginalPaymentReference(Rec);
        PaymentExistedBefore := PaymentBefore.Get(Rec."Merchant Account", PaymentReference);
        if PaymentExistedBefore then
            PreviousLifecycleStatus := PaymentBefore."Adyen Lifecycle Status";
        Rec.Status := Rec.Status::Processing;
        Rec.Modify(true);
        MessageType := EventDisposition.NormalizeMessageType(Rec."Message Type");

        if Rec.Source = Rec.Source::Report then begin
            ReportRun.Get(Rec."Report Run Entry No.");
            if ReportRun.Status = ReportRun.Status::Ready then begin
                ReportRun.Status := ReportRun.Status::Processing;
                ReportRun.Modify(true);
            end;
        end;

        if MessageType = 'REPORTAVAILABLE' then
            ReportManagement.RegisterAvailable(Rec)
        else
            if MessageType = 'AUTHORISATION' then begin
                if Rec."Success Provided" and Rec.Success then
                    PaymentState.ImportPositivePaymentWithResult(Rec, false, DispositionReason, LifecycleApplied)
                else
                    EventDisposition.MarkFailedAuthorisation(Rec);
            end else
                if (Rec.Source = Rec.Source::Report) and PaymentState.IsPositiveReportMessage(MessageType) then
                    ReportReconciler.ReconcilePositiveLifecycleWithResult(Rec, DispositionReason, LifecycleApplied)
                else
                    if PaymentState.IsAdverseMessage(MessageType) then
                        PaymentState.ApplyAdverseEventWithResult(Rec, DispositionReason, LifecycleApplied)
                    else
                        EventDisposition.MarkUnsupported(Rec);

        if DispositionReason <> '' then
            EventDisposition.SetReason(Rec, DispositionReason);

        if Rec.Status = Rec.Status::Processing then
            Rec.Status := Rec.Status::Processed;
        RecordLifecycleOutcome(Rec, PaymentReference, PaymentExistedBefore, PreviousLifecycleStatus, LifecycleApplied);
        Rec."Processed At UTC" := CurrentDateTime();
        Rec."Last Error" := '';
        Rec.Modify(true);
    end;

    local procedure ClearLifecycleOutcome(var EventEntry: Record "Adyen Event Entry")
    begin
        EventEntry."Previous Lifecycle Status" := EventEntry."Previous Lifecycle Status"::Unknown;
        EventEntry."Resulting Lifecycle Status" := EventEntry."Resulting Lifecycle Status"::Unknown;
        EventEntry."Lifecycle Effect" := EventEntry."Lifecycle Effect"::Unknown;
    end;

    local procedure RecordLifecycleOutcome(var EventEntry: Record "Adyen Event Entry"; PaymentReference: Code[50]; PaymentExistedBefore: Boolean; PreviousLifecycleStatus: Enum "Adyen Lifecycle Status"; LifecycleApplied: Boolean)
    var
        PaymentAfter: Record "Imported Adyen Payment";
        PaymentExistsAfter: Boolean;
    begin
        if PaymentExistedBefore then
            EventEntry."Previous Lifecycle Status" := PreviousLifecycleStatus;

        PaymentExistsAfter := PaymentAfter.Get(EventEntry."Merchant Account", PaymentReference);
        if PaymentExistsAfter then
            EventEntry."Resulting Lifecycle Status" := PaymentAfter."Adyen Lifecycle Status";

        if not LifecycleApplied then begin
            EventEntry."Lifecycle Effect" := EventEntry."Lifecycle Effect"::NotApplied;
            exit;
        end;

        if (not PaymentExistedBefore) or
           (PreviousLifecycleStatus <> EventEntry."Resulting Lifecycle Status")
        then
            EventEntry."Lifecycle Effect" := EventEntry."Lifecycle Effect"::Changed
        else
            EventEntry."Lifecycle Effect" := EventEntry."Lifecycle Effect"::AppliedWithoutChange;
    end;

}
