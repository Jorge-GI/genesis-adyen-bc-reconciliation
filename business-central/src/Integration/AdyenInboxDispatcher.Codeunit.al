codeunit 72030 "Adyen Inbox Dispatcher"
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    var
        Setup: Record "Adyen Setup";
        TransportId: Code[64];
        ProcessedCount: Integer;
    begin
        Setup.GetRecordOnce();
        if not Setup.Enabled then
            exit;

        while (ProcessedCount < 50) and FindNextProcessable(TransportId) do begin
            ClearLastError();
            if TryProcessEntry(TransportId) then
                MarkProcessed(TransportId)
            else
                MarkError(TransportId, GetLastErrorText());
            Commit();
            ProcessedCount += 1;
        end;

        FinalizeReadyReports();
        CheckReportDeadline();
    end;

    local procedure FindNextProcessable(var TransportId: Code[64]): Boolean
    var
        InboxEntry: Record "Adyen Inbox Entry";
        ReportRun: Record "Adyen Report Run";
    begin
        InboxEntry.SetCurrentKey(Status, "Occurred At UTC");
        InboxEntry.SetRange(Status, InboxEntry.Status::Received);
        if InboxEntry.FindSet() then
            repeat
                if InboxEntry.Source = InboxEntry.Source::Webhook then begin
                    TransportId := InboxEntry."Transport ID";
                    exit(true);
                end;
                if ReportRun.Get(InboxEntry."Report Run ID") and
                   (ReportRun.Status in [ReportRun.Status::Ready, ReportRun.Status::Processing])
                then begin
                    TransportId := InboxEntry."Transport ID";
                    exit(true);
                end;
            until InboxEntry.Next() = 0;
        exit(false);
    end;

    [TryFunction]
    local procedure TryProcessEntry(TransportId: Code[64])
    var
        InboxEntry: Record "Adyen Inbox Entry";
        PaymentState: Codeunit "Adyen Payment State Mgt.";
        ReportReconciler: Codeunit "Adyen Report Reconciler";
        MessageType: Text;
    begin
        InboxEntry.Get(TransportId);
        InboxEntry.Status := InboxEntry.Status::Processing;
        InboxEntry.Modify(true);
        MessageType := UpperCase(InboxEntry."Message Type");

        if InboxEntry.Source = InboxEntry.Source::Webhook then begin
            if MessageType = 'AUTHORISATION' then begin
                if InboxEntry."Success Provided" and InboxEntry.Success then
                    PaymentState.ImportPositivePayment(InboxEntry, false);
                exit;
            end;
            if PaymentState.IsAdverseMessage(MessageType) then
                PaymentState.ApplyAdverseEvent(InboxEntry);
            exit;
        end;

        if MessageType = 'SENTFORSETTLE' then begin
            ReportReconciler.ReconcileSentForSettle(InboxEntry);
            exit;
        end;
        if PaymentState.IsAdverseMessage(MessageType) then
            PaymentState.ApplyAdverseEvent(InboxEntry);
    end;

    local procedure MarkProcessed(TransportId: Code[64])
    var
        InboxEntry: Record "Adyen Inbox Entry";
    begin
        InboxEntry.Get(TransportId);
        InboxEntry.Status := InboxEntry.Status::Processed;
        InboxEntry."Processed At UTC" := CurrentDateTime();
        InboxEntry."Last Error" := '';
        InboxEntry.Modify(true);
    end;

    local procedure MarkError(TransportId: Code[64]; ErrorText: Text)
    var
        InboxEntry: Record "Adyen Inbox Entry";
    begin
        InboxEntry.Get(TransportId);
        InboxEntry.Status := InboxEntry.Status::Error;
        InboxEntry."Retry Count" += 1;
        InboxEntry."Last Error" := CopyStr(ErrorText, 1, MaxStrLen(InboxEntry."Last Error"));
        InboxEntry.Modify(true);
    end;

    local procedure FinalizeReadyReports()
    var
        InboxEntry: Record "Adyen Inbox Entry";
        ReportRun: Record "Adyen Report Run";
    begin
        ReportRun.SetRange(Status, ReportRun.Status::Ready);
        if ReportRun.FindSet(true) then
            repeat
                InboxEntry.SetRange("Report Run ID", ReportRun."External Report ID");
                InboxEntry.SetFilter(Status, '%1|%2|%3', InboxEntry.Status::Received, InboxEntry.Status::Processing, InboxEntry.Status::Error);
                if InboxEntry.IsEmpty() then begin
                    ReportRun.Status := ReportRun.Status::Processed;
                    ReportRun."Processed At UTC" := CurrentDateTime();
                    ReportRun.Modify(true);
                end;
                InboxEntry.Reset();
            until ReportRun.Next() = 0;
    end;

    local procedure CheckReportDeadline()
    var
        Setup: Record "Adyen Setup";
        CustomDimensions: Dictionary of [Text, Text];
        AlertMessage: Text[250];
        ExpectedReportDate: Date;
    begin
        Setup.GetRecordOnce();
        ExpectedReportDate := CalcDate('<-1D>', Today());
        if (Time() >= Setup."Report Deadline") and (Setup."Last Ready Report Date" < ExpectedReportDate) then begin
            AlertMessage := CopyStr(
                StrSubstNo('The expected Adyen report for %1 was not ready by %2.', ExpectedReportDate, Setup."Report Deadline"),
                1, MaxStrLen(AlertMessage));
            if not Setup."Report Overdue" then begin
                CustomDimensions.Add('Category', 'AdyenReconciliation');
                CustomDimensions.Add('Company', CompanyName());
                Session.LogMessage('ADYEN001', AlertMessage, Verbosity::Warning, DataClassification::CustomerContent,
                    TelemetryScope::ExtensionPublisher, CustomDimensions);
            end;
            Setup."Report Overdue" := true;
            Setup."Report Alert Message" := AlertMessage;
        end else begin
            Setup."Report Overdue" := false;
            Setup."Report Alert Message" := '';
        end;
        Setup.Modify(true);
    end;
}
