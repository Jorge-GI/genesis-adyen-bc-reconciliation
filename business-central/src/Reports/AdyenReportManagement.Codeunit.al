codeunit 72043 "Adyen Report Management"
{
    procedure RegisterAvailable(EventEntry: Record "Adyen Event Entry")
    var
        ReportRun: Record "Adyen Report Run";
    begin
        if EventEntry."External Report ID" = '' then
            Error('REPORT_AVAILABLE event %1 has no report identifier.', EventEntry."Transport ID");
        ReportRun.SetCurrentKey("Merchant Account", "External Report ID");
        ReportRun.SetRange("Merchant Account", EventEntry."Merchant Account");
        ReportRun.SetRange("External Report ID", EventEntry."External Report ID");
        if ReportRun.FindFirst() then begin
            ReportRun.CalcFields(Content);
            if (ReportRun.Status = ReportRun.Status::Error) and not ReportRun.Content.HasValue() then begin
                ReportRun."Download URL" := EventEntry.Reason;
                ReportRun.Status := ReportRun.Status::Requested;
                ReportRun."Last Error" := '';
                ReportRun.Modify(true);
            end;
            exit;
        end;

        if EventEntry.Reason = '' then
            Error('REPORT_AVAILABLE event %1 has no download URL.', EventEntry."Transport ID");
        ReportRun.Init();
        ReportRun."Merchant Account" := EventEntry."Merchant Account";
        ReportRun."External Report ID" := EventEntry."External Report ID";
        ReportRun."Download URL" := EventEntry.Reason;
        ReportRun.Insert(true);
    end;
}
