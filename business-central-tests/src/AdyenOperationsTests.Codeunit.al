codeunit 72156 "Adyen Operations Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure RetentionPurgesOnlyBlobContent()
    var
        EventEntry: Record "Adyen Event Entry";
        Merchant: Record "Adyen Merchant";
        Payment: Record "Imported Adyen Payment";
        ReportRun: Record "Adyen Report Run";
        Setup: Record "Adyen Setup";
        WebhookRequest: Record "Adyen Webhook Request";
        Retention: Codeunit "Adyen Retention";
        ContentOutStream: OutStream;
        EventId: Code[64];
        WebhookEntryNo: BigInteger;
        ReportEntryNo: BigInteger;
    begin
        Setup.GetRecordOnce();
        Setup."Raw Retention Days" := 1;
        Setup."Report Retention Months" := 1;
        Setup.Modify(true);
        InsertMerchant(Merchant, 'RetentionMerchant');

        WebhookRequest.Init();
        WebhookRequest."Received At UTC" := CreateDateTime(CalcDate('<-2D>', Today()), 000000T);
        WebhookRequest."Payload Hash" := 'RETENTION-WEBHOOK-HASH';
        WebhookRequest.Payload.CreateOutStream(ContentOutStream, TextEncoding::UTF8);
        ContentOutStream.WriteText('{"retained":true}');
        WebhookRequest.Insert(true);
        WebhookEntryNo := WebhookRequest."Entry No.";

        ReportRun.Init();
        ReportRun."Merchant Account" := Merchant."Merchant Account";
        ReportRun."External Report ID" := 'report_2026_01_01.csv';
        ReportRun."Download URL" := 'https://ca-test.adyen.com/report.csv';
        ReportRun.Insert(true);
        ReportRun."Report Date" := CalcDate('<-2M>', Today());
        ReportRun.Content.CreateOutStream(ContentOutStream, TextEncoding::UTF8);
        ContentOutStream.WriteText('csv-content');
        ReportRun.Modify(true);
        ReportEntryNo := ReportRun."Entry No.";

        EventId := 'RETENTION-EVENT';
        EventEntry.Init();
        EventEntry."Transport ID" := EventId;
        EventEntry."Logical Event Key" := 'RETENTION-LOGICAL';
        EventEntry."Message Type" := 'AUTHORISATION';
        EventEntry."Merchant Account" := Merchant."Merchant Account";
        EventEntry."PSP Reference" := 'RETENTION-PSP';
        EventEntry."Webhook Request Entry No." := WebhookEntryNo;
        EventEntry."Payload Hash" := 'RETENTION-EVENT-HASH';
        EventEntry.Reason := 'Source reason';
        EventEntry."Disposition Reason" := 'Audit decision';
        EventEntry."Previous Lifecycle Status" := EventEntry."Previous Lifecycle Status"::Authorised;
        EventEntry."Resulting Lifecycle Status" := EventEntry."Resulting Lifecycle Status"::Authorised;
        EventEntry."Lifecycle Effect" := EventEntry."Lifecycle Effect"::NotApplied;
        EventEntry.Insert(true);

        Payment.Init();
        Payment."Merchant Account" := Merchant."Merchant Account";
        Payment."PSP Reference" := 'RETENTION-PSP';
        Payment.Insert(true);

        Retention.RunCleanup();

        WebhookRequest.Get(WebhookEntryNo);
        WebhookRequest.CalcFields(Payload);
        AssertTrue(WebhookRequest."Raw Content Purged" and not WebhookRequest.Payload.HasValue(), 'Raw webhook content must be purged and metadata retained.');
        ReportRun.Get(ReportEntryNo);
        ReportRun.CalcFields(Content);
        AssertTrue(ReportRun."Content Purged" and not ReportRun.Content.HasValue(), 'Report content must be purged and metadata retained.');
        AssertTrue(EventEntry.Get(EventId), 'Normalized events must survive cleanup.');
        AssertTrue(EventEntry."Webhook Request Entry No." = WebhookEntryNo, 'The event source link must survive cleanup.');
        AssertTrue(EventEntry."Payload Hash" = 'RETENTION-EVENT-HASH', 'The event hash must survive cleanup.');
        AssertTrue(EventEntry.Reason = 'Source reason', 'The original source reason must survive cleanup.');
        AssertTrue(EventEntry."Disposition Reason" = 'Audit decision', 'The decision reason must survive cleanup.');
        AssertTrue(EventEntry."Previous Lifecycle Status" = EventEntry."Previous Lifecycle Status"::Authorised, 'The previous lifecycle must survive cleanup.');
        AssertTrue(EventEntry."Resulting Lifecycle Status" = EventEntry."Resulting Lifecycle Status"::Authorised, 'The resulting lifecycle must survive cleanup.');
        AssertTrue(EventEntry."Lifecycle Effect" = EventEntry."Lifecycle Effect"::NotApplied, 'The recorded lifecycle effect must survive cleanup.');
        AssertTrue(Payment.Get(Merchant."Merchant Account", 'RETENTION-PSP'), 'Imported payments must survive cleanup.');
    end;

    [Test]
    procedure RetentionDoesNotPurgeAnUndownloadedReport()
    var
        Merchant: Record "Adyen Merchant";
        ReportRun: Record "Adyen Report Run";
        Setup: Record "Adyen Setup";
        Retention: Codeunit "Adyen Retention";
        ReportEntryNo: BigInteger;
    begin
        Setup.GetRecordOnce();
        Setup."Report Retention Months" := 1;
        Setup.Modify(true);
        InsertMerchant(Merchant, 'PendingRetentionMerchant');

        ReportRun.Init();
        ReportRun."Merchant Account" := Merchant."Merchant Account";
        ReportRun."External Report ID" := 'pending_2026_09_03.csv';
        ReportRun."Download URL" := 'https://ca-test.adyen.com/report.csv';
        ReportRun.Insert(true);
        ReportEntryNo := ReportRun."Entry No.";

        Retention.RunCleanup();

        ReportRun.Get(ReportEntryNo);
        AssertTrue(ReportRun."Report Date" = 0D, 'An undownloaded report must still have a blank report date.');
        AssertTrue(not ReportRun."Content Purged", 'Retention must not mark an undownloaded report as purged.');
        AssertTrue(ReportRun.Status = ReportRun.Status::Requested, 'Retention must leave an undownloaded report retryable.');
    end;

    [Test]
    procedure DailyDeadlineIsTrackedPerMerchant()
    var
        Merchant: Record "Adyen Merchant";
        Setup: Record "Adyen Setup";
        Dispatcher: Codeunit "Adyen Dispatcher";
        ExpectedReportDate: Date;
    begin
        Setup.GetRecordOnce();
        Setup."Report Deadline" := 0T;
        Setup.Modify(true);
        Merchant.DeleteAll(false);
        InsertMerchant(Merchant, 'DeadlineMerchantA');
        InsertMerchant(Merchant, 'DeadlineMerchantB');

        Dispatcher.CheckReportDeadlines();
        Merchant.Get('DeadlineMerchantA');
        AssertTrue(Merchant."Report Overdue", 'Merchant A must have its own overdue state.');
        Merchant.Get('DeadlineMerchantB');
        AssertTrue(Merchant."Report Overdue", 'Merchant B must have its own overdue state.');

        ExpectedReportDate := CalcDate('<-1D>', Today());
        Merchant.Get('DeadlineMerchantA');
        Merchant."Last Ready Report Date" := ExpectedReportDate;
        Merchant.Modify(true);
        Dispatcher.CheckReportDeadlines();
        Merchant.Get('DeadlineMerchantA');
        AssertTrue(not Merchant."Report Overdue", 'A received report must clear only its merchant overdue state.');
        Merchant.Get('DeadlineMerchantB');
        AssertTrue(Merchant."Report Overdue", 'Another merchant must remain overdue.');
    end;

    local procedure InsertMerchant(var Merchant: Record "Adyen Merchant"; MerchantAccount: Text)
    begin
        Merchant.Init();
        Merchant."Merchant Account" := MerchantAccount;
        Merchant.Enabled := true;
        Merchant.Insert(true);
    end;

    local procedure AssertTrue(Actual: Boolean; FailureMessage: Text)
    begin
        if not Actual then
            Error(FailureMessage);
    end;
}
