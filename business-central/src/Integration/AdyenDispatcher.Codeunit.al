codeunit 72044 "Adyen Dispatcher"
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    var
        Setup: Record "Adyen Setup";
    begin
        if GuiAllowed() then
            Error('The Adyen dispatcher must run as a scheduled background job. Set the Job Queue Entry to Ready instead of using Run once (Foreground).');

        Setup.GetRecordOnce();
        if not Setup.Enabled then
            exit;

        ProcessWebhookRequests(Setup."Max Messages Per Run");
        ProcessOneReport();
        ProcessEvents(Setup."Max Messages Per Run");
        FinalizeReports();
        CheckReportDeadlines();
        RunRetentionIfDue();
    end;

    local procedure ProcessWebhookRequests(MaximumCount: Integer)
    var
        WebhookRequest: Record "Adyen Webhook Request";
        EntryNo: BigInteger;
        ProcessedCount: Integer;
    begin
        while (ProcessedCount < MaximumCount) and FindNextWebhookRequest(EntryNo) do begin
            WebhookRequest.Get(EntryNo);
            Commit();

            ClearLastError();
            WebhookRequest.Get(EntryNo);
            if not Codeunit.Run(Codeunit::"Adyen Webhook Worker", WebhookRequest) then
                MarkWebhookError(EntryNo, GetLastErrorText());
            Commit();
            ProcessedCount += 1;
        end;
    end;

    local procedure FindNextWebhookRequest(var EntryNo: BigInteger): Boolean
    var
        WebhookRequest: Record "Adyen Webhook Request";
    begin
        WebhookRequest.SetCurrentKey(Status, "Received At UTC");
        WebhookRequest.SetRange(Status, WebhookRequest.Status::Received);
        if not WebhookRequest.FindFirst() then
            exit(false);
        EntryNo := WebhookRequest."Entry No.";
        exit(true);
    end;

    local procedure MarkWebhookError(EntryNo: BigInteger; ErrorText: Text)
    var
        WebhookRequest: Record "Adyen Webhook Request";
    begin
        WebhookRequest.Get(EntryNo);
        WebhookRequest.Status := WebhookRequest.Status::Error;
        WebhookRequest."Retry Count" += 1;
        WebhookRequest."Last Error" := CopyStr(ErrorText, 1, MaxStrLen(WebhookRequest."Last Error"));
        WebhookRequest.Modify(true);
    end;

    local procedure ProcessOneReport()
    var
        ReportRun: Record "Adyen Report Run";
        EntryNo: BigInteger;
    begin
        ReportRun.SetCurrentKey(Status, "Requested At UTC");
        ReportRun.SetRange(Status, ReportRun.Status::Loading);
        if ReportRun.FindFirst() then begin
            ProcessReport(ReportRun."Entry No.");
            exit;
        end;

        ReportRun.Reset();
        ReportRun.SetCurrentKey(Status, "Requested At UTC");
        ReportRun.SetRange(Status, ReportRun.Status::Requested);
        if not ReportRun.FindFirst() then
            exit;
        EntryNo := ReportRun."Entry No.";

        ProcessReport(EntryNo);
    end;

    internal procedure ProcessReport(EntryNo: BigInteger)
    var
        ReportRun: Record "Adyen Report Run";
    begin
        ReportRun.Get(EntryNo);
        if not (ReportRun.Status in [ReportRun.Status::Requested, ReportRun.Status::Loading]) then
            Error('Report run %1 cannot be processed from status %2.', EntryNo, ReportRun.Status);

        if not RunReportPhase(EntryNo) then
            exit;

        ReportRun.Get(EntryNo);
        if ReportRun.Status = ReportRun.Status::Loading then
            RunReportPhase(EntryNo);
    end;

    local procedure RunReportPhase(EntryNo: BigInteger): Boolean
    var
        ReportRun: Record "Adyen Report Run";
    begin
        Commit();
        ClearLastError();
        ReportRun.Get(EntryNo);
        if not Codeunit.Run(Codeunit::"Adyen Report Worker", ReportRun) then begin
            MarkReportError(EntryNo, GetLastErrorText());
            Commit();
            exit(false);
        end;
        Commit();
        exit(true);
    end;

    local procedure MarkReportError(EntryNo: BigInteger; ErrorText: Text)
    var
        ReportRun: Record "Adyen Report Run";
    begin
        ReportRun.Get(EntryNo);
        ReportRun.Status := ReportRun.Status::Error;
        ReportRun."Retry Count" += 1;
        ReportRun."Last Error" := CopyStr(ErrorText, 1, MaxStrLen(ReportRun."Last Error"));
        ReportRun.Modify(true);
    end;

    local procedure ProcessEvents(MaximumCount: Integer)
    var
        EventEntry: Record "Adyen Event Entry";
        TransportId: Code[64];
        ProcessedCount: Integer;
    begin
        while (ProcessedCount < MaximumCount) and FindNextEvent(TransportId) do begin
            EventEntry.Get(TransportId);
            Commit();

            ClearLastError();
            EventEntry.Get(TransportId);
            if not Codeunit.Run(Codeunit::"Adyen Event Worker", EventEntry) then
                MarkEventError(TransportId, GetLastErrorText());
            Commit();
            ProcessedCount += 1;
        end;
    end;

    local procedure FindNextEvent(var TransportId: Code[64]): Boolean
    var
        EventEntry: Record "Adyen Event Entry";
        ReportRun: Record "Adyen Report Run";
    begin
        EventEntry.SetCurrentKey(Status, "Occurred At UTC");
        EventEntry.SetRange(Status, EventEntry.Status::Received);
        if EventEntry.FindSet() then
            repeat
                if EventEntry.Source = EventEntry.Source::Webhook then begin
                    TransportId := EventEntry."Transport ID";
                    exit(true);
                end;
                if ReportRun.Get(EventEntry."Report Run Entry No.") and
                   (ReportRun.Status in [ReportRun.Status::Ready, ReportRun.Status::Processing])
                then begin
                    TransportId := EventEntry."Transport ID";
                    exit(true);
                end;
            until EventEntry.Next() = 0;
        exit(false);
    end;

    local procedure MarkEventError(TransportId: Code[64]; ErrorText: Text)
    var
        EventEntry: Record "Adyen Event Entry";
    begin
        EventEntry.Get(TransportId);
        EventEntry.Status := EventEntry.Status::Error;
        EventEntry."Disposition Reason" := '';
        EventEntry."Retry Count" += 1;
        EventEntry."Last Error" := CopyStr(ErrorText, 1, MaxStrLen(EventEntry."Last Error"));
        EventEntry.Modify(true);
    end;

    local procedure FinalizeReports()
    var
        EventEntry: Record "Adyen Event Entry";
        ReportRun: Record "Adyen Report Run";
    begin
        ReportRun.SetFilter(Status, '%1|%2', ReportRun.Status::Ready, ReportRun.Status::Processing);
        if ReportRun.FindSet(true) then
            repeat
                EventEntry.SetRange("Report Run Entry No.", ReportRun."Entry No.");
                EventEntry.SetFilter(Status, '%1|%2|%3', EventEntry.Status::Received, EventEntry.Status::Processing, EventEntry.Status::Error);
                if EventEntry.IsEmpty() then begin
                    ReportRun.Status := ReportRun.Status::Processed;
                    ReportRun."Processed At UTC" := CurrentDateTime();
                    ReportRun.Modify(true);
                end;
                EventEntry.Reset();
            until ReportRun.Next() = 0;
    end;

    procedure CheckReportDeadlines()
    var
        Setup: Record "Adyen Setup";
        Merchant: Record "Adyen Merchant";
        CustomDimensions: Dictionary of [Text, Text];
        ExpectedReportDate: Date;
        AlertMessage: Text[250];
    begin
        Setup.GetRecordOnce();
        ExpectedReportDate := CalcDate('<-1D>', Today());
        Merchant.SetRange(Enabled, true);
        if Merchant.FindSet(true) then
            repeat
                if (Time() >= Setup."Report Deadline") and (Merchant."Last Ready Report Date" < ExpectedReportDate) then begin
                    AlertMessage := CopyStr(
                        StrSubstNo('The expected Adyen report for merchant %1 and date %2 was not ready by %3.',
                            Merchant."Merchant Account", ExpectedReportDate, Setup."Report Deadline"),
                        1, MaxStrLen(AlertMessage));
                    if not Merchant."Report Overdue" then begin
                        Clear(CustomDimensions);
                        CustomDimensions.Add('Category', 'AdyenReconciliation');
                        CustomDimensions.Add('Company', CompanyName());
                        CustomDimensions.Add('Merchant', Merchant."Merchant Account");
                        Session.LogMessage('ADYEN001', AlertMessage, Verbosity::Warning, DataClassification::CustomerContent,
                            TelemetryScope::ExtensionPublisher, CustomDimensions);
                    end;
                    Merchant."Report Overdue" := true;
                    Merchant."Report Alert Message" := AlertMessage;
                    Merchant.Modify(true);
                end else
                    if Merchant."Report Overdue" then begin
                        Merchant."Report Overdue" := false;
                        Merchant."Report Alert Message" := '';
                        Merchant.Modify(true);
                    end;
            until Merchant.Next() = 0;
    end;

    local procedure RunRetentionIfDue()
    var
        Setup: Record "Adyen Setup";
        Retention: Codeunit "Adyen Retention";
    begin
        Setup.GetRecordOnce();
        if (Setup."Last Cleanup At UTC" <> 0DT) and (DT2Date(Setup."Last Cleanup At UTC") = Today()) then
            exit;
        Retention.RunCleanup();
    end;
}
