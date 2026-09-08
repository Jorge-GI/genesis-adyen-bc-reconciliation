codeunit 72050 "Adyen Event Worker"
{
    TableNo = "Adyen Event Entry";

    trigger OnRun()
    var
        ReportRun: Record "Adyen Report Run";
        PaymentState: Codeunit "Adyen Payment State";
        ReportManagement: Codeunit "Adyen Report Management";
        ReportReconciler: Codeunit "Adyen Report Reconciler";
        MessageType: Text;
    begin
        Rec.Status := Rec.Status::Processing;
        Rec.Modify(true);
        MessageType := NormalizeMessageType(Rec."Message Type");

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
                    PaymentState.ImportPositivePayment(Rec, false)
                else
                    Rec.Status := Rec.Status::Ignored;
            end else
                if (Rec.Source = Rec.Source::Report) and (MessageType = 'SENTFORSETTLE') then
                    ReportReconciler.ReconcileSentForSettle(Rec)
                else
                    if PaymentState.IsAdverseMessage(MessageType) then
                        PaymentState.ApplyAdverseEvent(Rec)
                    else
                        Rec.Status := Rec.Status::Ignored;

        if Rec.Status = Rec.Status::Processing then
            Rec.Status := Rec.Status::Processed;
        Rec."Processed At UTC" := CurrentDateTime();
        Rec."Last Error" := '';
        Rec.Modify(true);
    end;

    local procedure NormalizeMessageType(MessageType: Text): Text
    begin
        exit(UpperCase(DelChr(MessageType, '=', '_- ')));
    end;
}
