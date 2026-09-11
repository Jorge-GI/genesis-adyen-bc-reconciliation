codeunit 72159 "Adyen Role Center Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure CueCountsIncludeOnlyActionableRecords()
    var
        Cue: Record "Adyen Role Center Cue";
        JobQueueEntry: Record "Job Queue Entry";
        ActiveReportRunsBefore: Integer;
        AdyenTasksFailedBefore: Integer;
        AdyenTasksInProcessBefore: Integer;
        AdyenTasksInQueueBefore: Integer;
        AutomaticallyPostedBefore: Integer;
        EventErrorsBefore: Integer;
        ManuallyPostedBefore: Integer;
        ManualJournalDraftsBefore: Integer;
        OverdueMerchantsBefore: Integer;
        PendingEventEntriesBefore: Integer;
        PendingWebhookRequestsBefore: Integer;
        PaymentExceptionsBefore: Integer;
        PostedAdyenPaymentsBefore: Integer;
        ReadyToPostBefore: Integer;
        ReportErrorsBefore: Integer;
        TotalImportedPaymentsBefore: Integer;
        UnclassifiedPostedBefore: Integer;
        WebhookErrorsBefore: Integer;
    begin
        TestIdentity := CopyStr(Format(CreateGuid()), 1, MaxStrLen(TestIdentity));
        MerchantAccount := CopyStr('CueMerchant' + TestIdentity, 1, MaxStrLen(MerchantAccount));
        if not Cue.Get() then begin
            Cue.Init();
            Cue.Insert();
        end;
        Cue.CalcFields("Payment Exceptions", "Ready to Post", "Total Imported Payments", "Posted Adyen Payments", "Automatically Posted",
          "Manually Posted", "Unclassified Posted", "Manual Journal Drafts",
          "Pending Webhook Requests", "Webhook Errors", "Pending Event Entries", "Event Errors",
          "Active Report Runs", "Report Errors", "Overdue Merchants", "Adyen Tasks Failed", "Adyen Tasks In Process", "Adyen Tasks In Queue");
        PaymentExceptionsBefore := Cue."Payment Exceptions";
        ReadyToPostBefore := Cue."Ready to Post";
        TotalImportedPaymentsBefore := Cue."Total Imported Payments";
        PostedAdyenPaymentsBefore := Cue."Posted Adyen Payments";
        AutomaticallyPostedBefore := Cue."Automatically Posted";
        ManuallyPostedBefore := Cue."Manually Posted";
        UnclassifiedPostedBefore := Cue."Unclassified Posted";
        ManualJournalDraftsBefore := Cue."Manual Journal Drafts";
        PendingWebhookRequestsBefore := Cue."Pending Webhook Requests";
        WebhookErrorsBefore := Cue."Webhook Errors";
        PendingEventEntriesBefore := Cue."Pending Event Entries";
        EventErrorsBefore := Cue."Event Errors";
        ActiveReportRunsBefore := Cue."Active Report Runs";
        ReportErrorsBefore := Cue."Report Errors";
        OverdueMerchantsBefore := Cue."Overdue Merchants";
        AdyenTasksFailedBefore := Cue."Adyen Tasks Failed";
        AdyenTasksInProcessBefore := Cue."Adyen Tasks In Process";
        AdyenTasksInQueueBefore := Cue."Adyen Tasks In Queue";

        InsertMerchant();

        InsertPayment('IMPORTED', Enum::"Adyen Payment Status"::Imported);
        InsertPayment('ERROR', Enum::"Adyen Payment Status"::Error);
        InsertPayment('REVERSAL', Enum::"Adyen Payment Status"::ReversalRequired);
        InsertPayment('CONFLICT', Enum::"Adyen Payment Status"::DataConflict);
        InsertPayment('READY', Enum::"Adyen Payment Status"::ReadyToPost);
        InsertPayment('MANUAL', Enum::"Adyen Payment Status"::ManualJournalCreated);
        InsertPayment('POSTED', Enum::"Adyen Payment Status"::PostedApplied);
        InsertPostedPayment('AUTO-POSTED', Enum::"Adyen Payment Status"::PostedApplied, 710001, Enum::"Adyen Posting Origin"::Automatic);
        InsertPostedPayment('MANUAL-EXACT-POSTED', Enum::"Adyen Payment Status"::PostedApplied, 710002, Enum::"Adyen Posting Origin"::ManualExactMatch);
        InsertPostedPayment('MANUAL-JOURNAL-POSTED', Enum::"Adyen Payment Status"::ManuallyReconciled, 710003, Enum::"Adyen Posting Origin"::ManualJournal);
        InsertPostedPayment('UNCLASSIFIED-POSTED', Enum::"Adyen Payment Status"::PostedApplied, 710004, Enum::"Adyen Posting Origin"::Unclassified);
        InsertUnpostedPaymentWithOrigin('UNPOSTED-AUTO', Enum::"Adyen Posting Origin"::Automatic);

        InsertWebhook('WEBHOOK-RECEIVED', Enum::"Adyen Process Status"::Received);
        InsertWebhook('WEBHOOK-PROCESSING', Enum::"Adyen Process Status"::Processing);
        InsertWebhook('WEBHOOK-ERROR', Enum::"Adyen Process Status"::Error);
        InsertWebhook('WEBHOOK-DONE', Enum::"Adyen Process Status"::Processed);
        InsertWebhook('WEBHOOK-IGNORED', Enum::"Adyen Process Status"::Ignored);
        InsertEvent('EVENT-RECEIVED', Enum::"Adyen Process Status"::Received);
        InsertEvent('EVENT-PROCESSING', Enum::"Adyen Process Status"::Processing);
        InsertEvent('EVENT-ERROR', Enum::"Adyen Process Status"::Error);
        InsertEvent('EVENT-DONE', Enum::"Adyen Process Status"::Processed);
        InsertEvent('EVENT-IGNORED', Enum::"Adyen Process Status"::Ignored);
        InsertReport('REPORT-REQUESTED', Enum::"Adyen Report Run Status"::Requested);
        InsertReport('REPORT-DOWNLOADING', Enum::"Adyen Report Run Status"::Downloading);
        InsertReport('REPORT-LOADING', Enum::"Adyen Report Run Status"::Loading);
        InsertReport('REPORT-READY', Enum::"Adyen Report Run Status"::Ready);
        InsertReport('REPORT-PROCESSING', Enum::"Adyen Report Run Status"::Processing);
        InsertReport('REPORT-ERROR', Enum::"Adyen Report Run Status"::Error);
        InsertReport('REPORT-DONE', Enum::"Adyen Report Run Status"::Processed);
        InsertMerchantWithState(CopyStr('Overdue' + TestIdentity, 1, 80), true, true);
        InsertMerchantWithState(CopyStr('Current' + TestIdentity, 1, 80), true, false);
        InsertMerchantWithState(CopyStr('Disabled' + TestIdentity, 1, 80), false, true);
        InsertJobQueueEntry(Codeunit::"Adyen Dispatcher", JobQueueEntry.Status::Error);
        InsertJobQueueEntry(Codeunit::"Adyen Dispatcher", JobQueueEntry.Status::"In Process");
        InsertJobQueueEntry(Codeunit::"Adyen Dispatcher", JobQueueEntry.Status::Ready);
        InsertJobQueueEntry(Codeunit::"Adyen Dispatcher", JobQueueEntry.Status::Waiting);
        InsertJobQueueEntry(Codeunit::"Adyen Dispatcher", JobQueueEntry.Status::"On Hold");
        InsertJobQueueEntry(Codeunit::"Adyen Dispatcher", JobQueueEntry.Status::Finished);
        InsertJobQueueEntry(Codeunit::"Adyen Event Worker", JobQueueEntry.Status::Error);

        Cue.CalcFields("Payment Exceptions", "Ready to Post", "Total Imported Payments", "Posted Adyen Payments", "Automatically Posted",
          "Manually Posted", "Unclassified Posted", "Manual Journal Drafts",
          "Pending Webhook Requests", "Webhook Errors", "Pending Event Entries", "Event Errors",
          "Active Report Runs", "Report Errors", "Overdue Merchants", "Adyen Tasks Failed", "Adyen Tasks In Process", "Adyen Tasks In Queue");

        AssertEqualInteger(PaymentExceptionsBefore + 4, Cue."Payment Exceptions", 'The payment-exception cue must count only actionable payment states.');
        AssertEqualInteger(ReadyToPostBefore + 1, Cue."Ready to Post", 'The ready-to-post cue must count only payments ready for automatic posting.');
        AssertEqualInteger(TotalImportedPaymentsBefore + 12, Cue."Total Imported Payments", 'The imported-payment cue must count every imported payment regardless of status or posting route.');
        AssertEqualInteger(PostedAdyenPaymentsBefore + 4, Cue."Posted Adyen Payments", 'The posted-payment cue must count only payments linked to a posted customer ledger entry.');
        AssertEqualInteger(AutomaticallyPostedBefore + 1, Cue."Automatically Posted", 'The automatic-posting cue must count only posted automatic payments.');
        AssertEqualInteger(ManuallyPostedBefore + 2, Cue."Manually Posted", 'The manual-posting cue must combine posted exact-match and manual-journal payments.');
        AssertEqualInteger(UnclassifiedPostedBefore + 1, Cue."Unclassified Posted", 'The unclassified-posting cue must count only posted payments without a classified route.');
        AssertEqualInteger(Cue."Posted Adyen Payments", Cue."Automatically Posted" + Cue."Manually Posted" + Cue."Unclassified Posted", 'The posting-origin breakdown must reconcile to the posted-payment total.');
        AssertEqualInteger(ManualJournalDraftsBefore + 1, Cue."Manual Journal Drafts", 'The manual-draft cue must count only payments linked to a manual journal draft.');
        AssertEqualInteger(PendingWebhookRequestsBefore + 2, Cue."Pending Webhook Requests", 'The pending-webhook cue must count received and processing requests only.');
        AssertEqualInteger(WebhookErrorsBefore + 1, Cue."Webhook Errors", 'The webhook cue must count only errored webhook requests.');
        AssertEqualInteger(PendingEventEntriesBefore + 2, Cue."Pending Event Entries", 'The pending-event cue must count received and processing events only.');
        AssertEqualInteger(EventErrorsBefore + 1, Cue."Event Errors", 'The event cue must count only errored events.');
        AssertEqualInteger(ActiveReportRunsBefore + 5, Cue."Active Report Runs", 'The active-report cue must count every nonterminal processing state and exclude completed or errored runs.');
        AssertEqualInteger(ReportErrorsBefore + 1, Cue."Report Errors", 'The report cue must count only errored report runs.');
        AssertEqualInteger(OverdueMerchantsBefore + 1, Cue."Overdue Merchants", 'The overdue-merchant cue must count only enabled merchants with an overdue report.');
        AssertEqualInteger(AdyenTasksFailedBefore + 1, Cue."Adyen Tasks Failed", 'The failed-task cue must count only errored Adyen dispatcher entries.');
        AssertEqualInteger(AdyenTasksInProcessBefore + 1, Cue."Adyen Tasks In Process", 'The in-process cue must count only active Adyen dispatcher entries.');
        AssertEqualInteger(AdyenTasksInQueueBefore + 2, Cue."Adyen Tasks In Queue", 'The queued-task cue must count only ready and waiting Adyen dispatcher entries.');
    end;

    local procedure InsertMerchant()
    var
        Merchant: Record "Adyen Merchant";
    begin
        Merchant.Init();
        Merchant."Merchant Account" := MerchantAccount;
        Merchant.Enabled := true;
        Merchant.Insert(true);
    end;

    local procedure InsertPayment(PspReferencePrefix: Text; PaymentStatus: Enum "Adyen Payment Status")
    var
        Payment: Record "Imported Adyen Payment";
    begin
        Payment.Init();
        Payment."Merchant Account" := MerchantAccount;
        Payment."PSP Reference" := CopyStr(PspReferencePrefix + TestIdentity, 1, MaxStrLen(Payment."PSP Reference"));
        Payment.Status := PaymentStatus;
        Payment.Insert(true);
    end;

    local procedure InsertPostedPayment(PspReferencePrefix: Text; PaymentStatus: Enum "Adyen Payment Status"; PostedPaymentEntryNo: Integer; PostingOrigin: Enum "Adyen Posting Origin")
    var
        Payment: Record "Imported Adyen Payment";
    begin
        Payment.Init();
        Payment."Merchant Account" := MerchantAccount;
        Payment."PSP Reference" := CopyStr(PspReferencePrefix + TestIdentity, 1, MaxStrLen(Payment."PSP Reference"));
        Payment.Status := PaymentStatus;
        Payment."Posted Payment Entry No." := PostedPaymentEntryNo;
        Payment."Posting Origin" := PostingOrigin;
        Payment.Insert(true);
    end;

    local procedure InsertUnpostedPaymentWithOrigin(PspReferencePrefix: Text; PostingOrigin: Enum "Adyen Posting Origin")
    var
        Payment: Record "Imported Adyen Payment";
    begin
        Payment.Init();
        Payment."Merchant Account" := MerchantAccount;
        Payment."PSP Reference" := CopyStr(PspReferencePrefix + TestIdentity, 1, MaxStrLen(Payment."PSP Reference"));
        Payment.Status := Payment.Status::PostedApplied;
        Payment."Posting Origin" := PostingOrigin;
        Payment.Insert(true);
    end;

    local procedure InsertMerchantWithState(MerchantAccountValue: Text[80]; Enabled: Boolean; ReportOverdue: Boolean)
    var
        Merchant: Record "Adyen Merchant";
    begin
        Merchant.Init();
        Merchant."Merchant Account" := MerchantAccountValue;
        Merchant.Enabled := Enabled;
        Merchant."Report Overdue" := ReportOverdue;
        Merchant.Insert(true);
    end;

    local procedure InsertWebhook(PayloadHashPrefix: Text; ProcessStatus: Enum "Adyen Process Status")
    var
        WebhookRequest: Record "Adyen Webhook Request";
    begin
        WebhookRequest.Init();
        WebhookRequest."Payload Hash" := CopyStr(PayloadHashPrefix + TestIdentity, 1, MaxStrLen(WebhookRequest."Payload Hash"));
        WebhookRequest.Insert(true);
        WebhookRequest.Status := ProcessStatus;
        WebhookRequest.Modify(true);
    end;

    local procedure InsertEvent(TransportIdPrefix: Text; ProcessStatus: Enum "Adyen Process Status")
    var
        EventEntry: Record "Adyen Event Entry";
        TransportId: Code[64];
    begin
        TransportId := CopyStr(TransportIdPrefix + TestIdentity, 1, MaxStrLen(TransportId));
        EventEntry.Init();
        EventEntry."Transport ID" := TransportId;
        EventEntry."Logical Event Key" := TransportId;
        EventEntry."Message Type" := 'AUTHORISATION';
        EventEntry."Merchant Account" := MerchantAccount;
        EventEntry."PSP Reference" := TransportId;
        EventEntry.Insert(true);
        EventEntry.Status := ProcessStatus;
        EventEntry.Modify(true);
    end;

    local procedure InsertReport(ExternalReportIdPrefix: Text; ReportStatus: Enum "Adyen Report Run Status")
    var
        ReportRun: Record "Adyen Report Run";
    begin
        ReportRun.Init();
        ReportRun."Merchant Account" := MerchantAccount;
        ReportRun."External Report ID" := CopyStr(ExternalReportIdPrefix + TestIdentity, 1, MaxStrLen(ReportRun."External Report ID"));
        ReportRun."Download URL" := 'https://ca-test.adyen.com/report.csv';
        ReportRun.Insert(true);
        ReportRun.Status := ReportStatus;
        ReportRun.Modify(true);
    end;

    local procedure InsertJobQueueEntry(ObjectId: Integer; JobQueueStatus: Option Ready,"In Process",Error,"On Hold",Finished,"On Hold with Inactivity Timeout",Waiting)
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.Init();
        JobQueueEntry.ID := CreateGuid();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := ObjectId;
        JobQueueEntry.Description := CopyStr('Adyen role center test ' + TestIdentity, 1, MaxStrLen(JobQueueEntry.Description));
        JobQueueEntry.Status := JobQueueStatus;
        JobQueueEntry.Insert(true);
    end;

    local procedure AssertEqualInteger(Expected: Integer; Actual: Integer; FailureMessage: Text)
    begin
        if Expected <> Actual then
            Error('%1 Expected %2, actual %3.', FailureMessage, Expected, Actual);
    end;

    var
        MerchantAccount: Text[80];
        TestIdentity: Text[50];
}
