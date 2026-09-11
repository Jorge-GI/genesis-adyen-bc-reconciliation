codeunit 72045 "Adyen Retention"
{
    procedure RunCleanup()
    var
        Setup: Record "Adyen Setup";
        WebhookRequest: Record "Adyen Webhook Request";
        ReportRun: Record "Adyen Report Run";
        WebhookCutoff: DateTime;
        ReportCutoff: Date;
    begin
        Setup.GetRecordOnce();
        WebhookCutoff := CreateDateTime(CalcDate(StrSubstNo('<-%1D>', Setup."Raw Retention Days"), Today()), 000000T);
        WebhookRequest.SetAutoCalcFields(Payload);
        WebhookRequest.SetRange("Raw Content Purged", false);
        WebhookRequest.SetFilter("Received At UTC", '<%1', WebhookCutoff);
        if WebhookRequest.FindSet(true) then
            repeat
                if WebhookRequest.Payload.HasValue() then
                    Clear(WebhookRequest.Payload);
                WebhookRequest."Raw Content Purged" := true;
                WebhookRequest.Modify(true);
            until WebhookRequest.Next() = 0;

        ReportCutoff := CalcDate(StrSubstNo('<-%1M>', Setup."Report Retention Months"), Today());
        ReportRun.SetAutoCalcFields(Content);
        ReportRun.SetRange("Content Purged", false);
        ReportRun.SetFilter("Report Date", '<>%1&<%2', 0D, ReportCutoff);
        if ReportRun.FindSet(true) then
            repeat
                if ReportRun.Content.HasValue() then begin
                    Clear(ReportRun.Content);
                    ReportRun."Content Purged" := true;
                    ReportRun.Modify(true);
                end;
            until ReportRun.Next() = 0;

        Setup."Last Cleanup At UTC" := CurrentDateTime();
        Setup.Modify(true);
    end;
}
