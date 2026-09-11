codeunit 72158 "Adyen Page Sorting Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    [HandlerFunctions('WebhookRequestsPageHandler')]
    procedure WebhookRequestsOpenNewestFirstWithStatusFilter()
    var
        NewerRequest: Record "Adyen Webhook Request";
        OlderRequest: Record "Adyen Webhook Request";
        FilteredOutRequest: Record "Adyen Webhook Request";
    begin
        InsertWebhookRequest(OlderRequest, OlderDateTime(), OlderRequest.Status::Received);
        InsertWebhookRequest(NewerRequest, NewerDateTime(), NewerRequest.Status::Received);
        InsertWebhookRequest(FilteredOutRequest, NewestDateTime(), FilteredOutRequest.Status::Error);

        ExpectedFirstWebhookEntryNo := NewerRequest."Entry No.";
        ExpectedSecondWebhookEntryNo := OlderRequest."Entry No.";
        NewerRequest.SetRange(Status, NewerRequest.Status::Received);
        Page.Run(Page::"Adyen Webhook Requests", NewerRequest);
    end;

    [Test]
    [HandlerFunctions('EventEntriesPageHandler')]
    procedure EventEntriesOpenNewestFirstWithStatusFilter()
    var
        NewerEvent: Record "Adyen Event Entry";
        OlderEvent: Record "Adyen Event Entry";
        FilteredOutEvent: Record "Adyen Event Entry";
    begin
        InsertEvent(OlderEvent, SortMerchantAccount(), 'SORT-EVENT-OLD', 'SORT-EVENT-OLD', OlderDateTime(), OlderEvent.Status::Received);
        InsertEvent(NewerEvent, SortMerchantAccount(), 'SORT-EVENT-NEW', 'SORT-EVENT-NEW', NewerDateTime(), NewerEvent.Status::Received);
        InsertEvent(FilteredOutEvent, SortMerchantAccount(), 'SORT-EVENT-FILTERED', 'SORT-EVENT-FILTERED', NewestDateTime(), FilteredOutEvent.Status::Error);

        ExpectedFirstEventPspReference := NewerEvent."PSP Reference";
        ExpectedSecondEventPspReference := OlderEvent."PSP Reference";
        NewerEvent.SetRange(Status, NewerEvent.Status::Received);
        Page.Run(Page::"Adyen Event Entries", NewerEvent);
    end;

    [Test]
    procedure ImportedPaymentsOpenNewestFirst()
    var
        NewerPayment: Record "Imported Adyen Payment";
        OlderPayment: Record "Imported Adyen Payment";
        ImportedPayments: TestPage "Imported Adyen Payments";
    begin
        InsertPayment(OlderPayment, 'SORT-PAYMENT-A-OLD', OlderDateTime(), OlderPayment.Status::Imported, 0);
        InsertPayment(NewerPayment, 'SORT-PAYMENT-Z-NEW', NewerDateTime(), NewerPayment.Status::Imported, 0);
        OlderPayment."Event Date-Time" := NewestDateTime();
        OlderPayment."Latest Event At UTC" := NewestDateTime();
        OlderPayment.Modify(false);
        NewerPayment."Event Date-Time" := OlderDateTime();
        NewerPayment."Latest Event At UTC" := OlderDateTime();
        NewerPayment.Modify(false);

        ImportedPayments.OpenView();
        ImportedPayments.Filter.SetFilter("Merchant Account", SortMerchantAccount());
        AssertTrue(ImportedPayments.First(), 'The imported-payment page must contain records.');
        ImportedPayments."Created At UTC".AssertEquals(NewerPayment."Created At UTC");
        ImportedPayments."PSP Reference".AssertEquals(NewerPayment."PSP Reference");
        AssertTrue(ImportedPayments.Next(), 'The imported-payment page must contain the older record.');
        ImportedPayments."Created At UTC".AssertEquals(OlderPayment."Created At UTC");
        ImportedPayments."PSP Reference".AssertEquals(OlderPayment."PSP Reference");
        ImportedPayments.Close();
    end;

    [Test]
    [HandlerFunctions('ImportedPaymentsPageHandler')]
    procedure ImportedPaymentsPageRunOpensNewestCreatedFirst()
    var
        NewerPayment: Record "Imported Adyen Payment";
        OlderPayment: Record "Imported Adyen Payment";
    begin
        InsertPayment(OlderPayment, 'SORT-PAGERUN-A-OLD', OlderDateTime(), OlderPayment.Status::Imported, 0);
        InsertPayment(NewerPayment, 'SORT-PAGERUN-Z-NEW', NewerDateTime(), NewerPayment.Status::Imported, 0);
        SetConflictingLifecycleDates(OlderPayment, NewerPayment);

        SetExpectedImportedPayments(NewerPayment, OlderPayment);
        Page.Run(Page::"Imported Adyen Payments");
    end;

    [Test]
    [HandlerFunctions('ImportedPaymentsPageHandler')]
    procedure FilteredImportedPaymentsPageRunPreservesStatusAndSortsNewestCreatedFirst()
    var
        NewerPayment: Record "Imported Adyen Payment";
        OlderPayment: Record "Imported Adyen Payment";
        FilteredOutPayment: Record "Imported Adyen Payment";
    begin
        InsertPayment(OlderPayment, 'SORT-FILTERED-A-OLD', OlderDateTime(), OlderPayment.Status::ReadyToPost, 0);
        InsertPayment(NewerPayment, 'SORT-FILTERED-Z-NEW', NewerDateTime(), NewerPayment.Status::ReadyToPost, 0);
        InsertPayment(FilteredOutPayment, 'SORT-FILTERED-OUT', NewestDateTime(), FilteredOutPayment.Status::Imported, 0);
        SetConflictingLifecycleDates(OlderPayment, NewerPayment);

        SetExpectedImportedPayments(NewerPayment, OlderPayment);
        NewerPayment.SetRange(Status, NewerPayment.Status::ReadyToPost);
        NewerPayment.SetCurrentKey("Created At UTC", "Merchant Account", "PSP Reference");
        NewerPayment.Ascending(false);
        Page.Run(Page::"Imported Adyen Payments", NewerPayment);
    end;

    [Test]
    procedure PaymentExceptionsPreserveFilterAndOpenNewestCreatedFirst()
    var
        PaymentExceptions: TestPage "Adyen Payment Exceptions";
    begin
        InsertExceptionSortingPayments();
        PaymentExceptions.OpenView();
        PaymentExceptions.Filter.SetFilter("Merchant Account", SortMerchantAccount());
        AssertExceptionCreationOrder(PaymentExceptions);
        PaymentExceptions.Close();
    end;

    [Test]
    [HandlerFunctions('PaymentExceptionsPageHandler')]
    procedure PaymentExceptionsCueOpensNewestCreatedFirst()
    var
        Activities: TestPage "Adyen Activities";
    begin
        InsertExceptionSortingPayments();
        Activities.OpenView();
        Activities."Payment Exceptions".DrillDown();
        Activities.Close();
    end;

    [Test]
    [HandlerFunctions('PaymentExceptionsPageHandler')]
    procedure PaymentExceptionsQuickAccessOpensNewestCreatedFirst()
    var
        QuickAccess: TestPage "Adyen Role Center Actions";
    begin
        InsertExceptionSortingPayments();
        QuickAccess.OpenView();
        QuickAccess.PaymentExceptions.Invoke();
        QuickAccess.Close();
    end;

    [Test]
    [HandlerFunctions('FilteredPaymentExceptionsPageHandler')]
    procedure PaymentExceptionsPageRunPreservesIncomingFilters()
    var
        Payment: Record "Imported Adyen Payment";
    begin
        InsertExceptionSortingPayments();
        Payment.SetRange("Merchant Account", SortMerchantAccount());
        Payment.SetFilter(Status, '%1|%2', Payment.Status::Error, Payment.Status::ReversalRequired);
        Payment.SetCurrentKey("Merchant Account", "PSP Reference");
        Payment.Ascending(true);
        Page.Run(Page::"Adyen Payment Exceptions", Payment);
    end;

    [Test]
    procedure PostedPaymentsPreserveFilterAndOpenNewestFirst()
    var
        NewerPostedPayment: Record "Imported Adyen Payment";
        OlderPostedPayment: Record "Imported Adyen Payment";
        FilteredOutPayment: Record "Imported Adyen Payment";
        PostedPayments: TestPage "Posted Adyen Payments";
    begin
        InsertPayment(OlderPostedPayment, 'SORT-POSTED-OLD', OlderDateTime(), OlderPostedPayment.Status::PostedApplied, 2147483600);
        InsertPayment(NewerPostedPayment, 'SORT-POSTED-NEW', NewerDateTime(), NewerPostedPayment.Status::PostedApplied, 2147483601);
        InsertPayment(FilteredOutPayment, 'SORT-POSTED-FILTERED', NewestDateTime(), FilteredOutPayment.Status::ReadyToPost, 0);

        PostedPayments.OpenView();
        PostedPayments.Filter.SetFilter("Merchant Account", SortMerchantAccount());
        AssertTrue(PostedPayments.First(), 'The posted-payment page must contain records.');
        PostedPayments."PSP Reference".AssertEquals(NewerPostedPayment."PSP Reference");
        AssertTrue(PostedPayments.Next(), 'The posted-payment page must contain the older posted payment.');
        PostedPayments."PSP Reference".AssertEquals(OlderPostedPayment."PSP Reference");
        AssertTrue(not PostedPayments.Next(), 'The posted-payment page must exclude unposted records.');
        PostedPayments.Close();
    end;

    [Test]
    [HandlerFunctions('ReportRunsPageHandler')]
    procedure ReportRunsOpenNewestFirstWithStatusFilter()
    var
        NewerReport: Record "Adyen Report Run";
        OlderReport: Record "Adyen Report Run";
        FilteredOutReport: Record "Adyen Report Run";
    begin
        InsertReportRun(OlderReport, 'SORT-REPORT-OLD', OlderDateTime(), OlderReport.Status::Requested);
        InsertReportRun(NewerReport, 'SORT-REPORT-NEW', NewerDateTime(), NewerReport.Status::Requested);
        InsertReportRun(FilteredOutReport, 'SORT-REPORT-FILTERED', NewestDateTime(), FilteredOutReport.Status::Error);

        ExpectedFirstReportId := NewerReport."External Report ID";
        ExpectedSecondReportId := OlderReport."External Report ID";
        NewerReport.SetRange(Status, NewerReport.Status::Requested);
        Page.Run(Page::"Adyen Report Runs", NewerReport);
    end;

    [Test]
    [HandlerFunctions('LifecycleEventsPageHandler')]
    procedure LifecycleEventsPreservePaymentFilterAndOpenNewestFirst()
    var
        NewerEvent: Record "Adyen Event Entry";
        OlderEvent: Record "Adyen Event Entry";
        FilteredOutEvent: Record "Adyen Event Entry";
    begin
        InsertEvent(OlderEvent, SortMerchantAccount(), 'SORT-LIFECYCLE-OLD', 'SORT-LIFECYCLE', OlderDateTime(), OlderEvent.Status::Processed);
        InsertEvent(NewerEvent, SortMerchantAccount(), 'SORT-LIFECYCLE-NEW', 'SORT-LIFECYCLE', NewerDateTime(), NewerEvent.Status::Processed);
        InsertEvent(FilteredOutEvent, 'ZZZ-SORT-OTHER-MERCHANT', 'SORT-LIFECYCLE-FILTERED', 'SORT-LIFECYCLE', NewestDateTime(), FilteredOutEvent.Status::Processed);

        ExpectedFirstEventPspReference := NewerEvent."PSP Reference";
        ExpectedSecondEventPspReference := OlderEvent."PSP Reference";
        NewerEvent.SetCurrentKey("Merchant Account", "Payment PSP Reference", "Occurred At UTC");
        NewerEvent.SetRange("Merchant Account", SortMerchantAccount());
        NewerEvent.SetRange("Payment PSP Reference", NewerEvent."Payment PSP Reference");
        Page.Run(Page::"Adyen Payment Lifecycle Events", NewerEvent);
    end;

    [PageHandler]
    procedure SourceWebhookPageHandler(var WebhookRequests: TestPage "Adyen Webhook Requests")
    begin
        AssertTrue(WebhookRequests.First(), 'The lifecycle source request must remain available.');
        WebhookRequests."Entry No.".AssertEquals(ExpectedFirstWebhookEntryNo);
        WebhookRequests."Raw Content Purged".AssertEquals(ExpectedSourcePurged);
        AssertTrue(not WebhookRequests.Next(), 'Open Source must filter to the exact webhook request.');
        WebhookRequests.Close();
    end;

    [PageHandler]
    procedure SourceReportPageHandler(var ReportRuns: TestPage "Adyen Report Runs")
    begin
        AssertTrue(ReportRuns.First(), 'The lifecycle source report must remain available.');
        ReportRuns."External Report ID".AssertEquals(ExpectedFirstReportId);
        ReportRuns."Content Purged".AssertEquals(ExpectedSourcePurged);
        AssertTrue(not ReportRuns.Next(), 'Open Source must filter to the exact report run.');
        ReportRuns.Close();
    end;

    [Test]
    [HandlerFunctions('SourceWebhookPageHandler')]
    procedure LifecycleWebhookSourceOpensBeforeAndAfterContentPurge()
    var
        EventEntry: Record "Adyen Event Entry";
        WebhookRequest: Record "Adyen Webhook Request";
        OtherRequest: Record "Adyen Webhook Request";
        ContentOutStream: OutStream;
    begin
        InsertWebhookRequest(WebhookRequest, OlderDateTime(), WebhookRequest.Status::Processed);
        WebhookRequest.Payload.CreateOutStream(ContentOutStream, TextEncoding::UTF8);
        ContentOutStream.WriteText('{"audit":true}');
        WebhookRequest.Modify(false);
        InsertWebhookRequest(OtherRequest, NewerDateTime(), OtherRequest.Status::Processed);
        InsertEvent(EventEntry, SortMerchantAccount(), 'AUDIT-WEBHOOK', 'AUDIT-PAYMENT', OlderDateTime(), EventEntry.Status::Processed);
        EventEntry."Webhook Request Entry No." := WebhookRequest."Entry No.";
        EventEntry.Modify(false);

        ExpectedFirstWebhookEntryNo := WebhookRequest."Entry No.";
        ExpectedSourcePurged := false;
        OpenLifecycleSource(EventEntry);

        Clear(WebhookRequest.Payload);
        WebhookRequest."Raw Content Purged" := true;
        WebhookRequest.Modify(false);
        ExpectedSourcePurged := true;
        OpenLifecycleSource(EventEntry);
    end;

    [Test]
    [HandlerFunctions('SourceReportPageHandler')]
    procedure LifecycleReportSourceOpensBeforeAndAfterContentPurge()
    var
        EventEntry: Record "Adyen Event Entry";
        ReportRun: Record "Adyen Report Run";
        OtherReport: Record "Adyen Report Run";
        ContentOutStream: OutStream;
    begin
        InsertReportRun(ReportRun, 'AUDIT-SOURCE-REPORT', OlderDateTime(), ReportRun.Status::Processed);
        ReportRun.Content.CreateOutStream(ContentOutStream, TextEncoding::UTF8);
        ContentOutStream.WriteText('audit-content');
        ReportRun.Modify(false);
        InsertReportRun(OtherReport, 'AUDIT-OTHER-REPORT', NewerDateTime(), OtherReport.Status::Processed);
        InsertEvent(EventEntry, SortMerchantAccount(), 'AUDIT-REPORT', 'AUDIT-PAYMENT', OlderDateTime(), EventEntry.Status::Processed);
        EventEntry.Source := EventEntry.Source::Report;
        EventEntry."Report Run Entry No." := ReportRun."Entry No.";
        EventEntry.Modify(false);

        ExpectedFirstReportId := ReportRun."External Report ID";
        ExpectedSourcePurged := false;
        OpenLifecycleSource(EventEntry);

        Clear(ReportRun.Content);
        ReportRun."Content Purged" := true;
        ReportRun.Modify(false);
        ExpectedSourcePurged := true;
        OpenLifecycleSource(EventEntry);
    end;

    local procedure OpenLifecycleSource(EventEntry: Record "Adyen Event Entry")
    var
        LifecycleEvents: TestPage "Adyen Payment Lifecycle Events";
    begin
        LifecycleEvents.OpenView();
        LifecycleEvents.Filter.SetFilter("PSP Reference", EventEntry."PSP Reference");
        AssertTrue(LifecycleEvents.First(), 'The lifecycle event must remain available.');
        LifecycleEvents.OpenSource.Invoke();
        LifecycleEvents.Close();
    end;

    [PageHandler]
    procedure WebhookRequestsPageHandler(var WebhookRequests: TestPage "Adyen Webhook Requests")
    begin
        AssertTrue(WebhookRequests.First(), 'The filtered webhook request page must contain records.');
        WebhookRequests."Entry No.".AssertEquals(ExpectedFirstWebhookEntryNo);
        AssertTrue(WebhookRequests.Next(), 'The filtered webhook request page must contain the older record.');
        WebhookRequests."Entry No.".AssertEquals(ExpectedSecondWebhookEntryNo);
        WebhookRequests.Close();
    end;

    [PageHandler]
    procedure EventEntriesPageHandler(var EventEntries: TestPage "Adyen Event Entries")
    begin
        AssertTrue(EventEntries.First(), 'The filtered event-entry page must contain records.');
        EventEntries."PSP Reference".AssertEquals(ExpectedFirstEventPspReference);
        AssertTrue(EventEntries.Next(), 'The filtered event-entry page must contain the older record.');
        EventEntries."PSP Reference".AssertEquals(ExpectedSecondEventPspReference);
        EventEntries.Close();
    end;

    [PageHandler]
    procedure ReportRunsPageHandler(var ReportRuns: TestPage "Adyen Report Runs")
    begin
        AssertTrue(ReportRuns.First(), 'The filtered report-run page must contain records.');
        ReportRuns."External Report ID".AssertEquals(ExpectedFirstReportId);
        AssertTrue(ReportRuns.Next(), 'The filtered report-run page must contain the older report.');
        ReportRuns."External Report ID".AssertEquals(ExpectedSecondReportId);
        ReportRuns.Close();
    end;

    [PageHandler]
    procedure LifecycleEventsPageHandler(var LifecycleEvents: TestPage "Adyen Payment Lifecycle Events")
    begin
        AssertTrue(LifecycleEvents.First(), 'The filtered lifecycle-event page must contain records.');
        LifecycleEvents."PSP Reference".AssertEquals(ExpectedFirstEventPspReference);
        AssertTrue(LifecycleEvents.Next(), 'The filtered lifecycle-event page must contain the older event.');
        LifecycleEvents."PSP Reference".AssertEquals(ExpectedSecondEventPspReference);
        LifecycleEvents.Close();
    end;

    [PageHandler]
    procedure ImportedPaymentsPageHandler(var ImportedPayments: TestPage "Imported Adyen Payments")
    begin
        AssertTrue(ImportedPayments.First(), 'The imported-payment page must contain records.');
        ImportedPayments."Created At UTC".AssertEquals(ExpectedFirstPaymentCreatedAt);
        ImportedPayments."PSP Reference".AssertEquals(ExpectedFirstPaymentPspReference);
        AssertTrue(ImportedPayments.Next(), 'The imported-payment page must contain the older record.');
        ImportedPayments."Created At UTC".AssertEquals(ExpectedSecondPaymentCreatedAt);
        ImportedPayments."PSP Reference".AssertEquals(ExpectedSecondPaymentPspReference);
        ImportedPayments.Close();
    end;

    [PageHandler]
    procedure PaymentExceptionsPageHandler(var PaymentExceptions: TestPage "Adyen Payment Exceptions")
    begin
        PaymentExceptions.Filter.SetFilter("Merchant Account", SortMerchantAccount());
        AssertExceptionCreationOrder(PaymentExceptions);
        PaymentExceptions.Close();
    end;

    [PageHandler]
    procedure FilteredPaymentExceptionsPageHandler(var PaymentExceptions: TestPage "Adyen Payment Exceptions")
    begin
        AssertTrue(PaymentExceptions.First(), 'The filtered exception page must contain records.');
        PaymentExceptions."PSP Reference".AssertEquals('SORT-EXCEPTION-M-NEW');
        PaymentExceptions."Created At UTC".AssertEquals(NewestDateTime());
        AssertTrue(PaymentExceptions.Next(), 'The filtered exception page must contain the older error.');
        PaymentExceptions."PSP Reference".AssertEquals('SORT-EXCEPTION-A-MIDDLE');
        PaymentExceptions."Created At UTC".AssertEquals(NewerDateTime());
        AssertTrue(not PaymentExceptions.Next(), 'Opening the page must preserve the incoming merchant and status filters.');
        PaymentExceptions.Close();
    end;

    local procedure InsertExceptionSortingPayments()
    var
        OlderException: Record "Imported Adyen Payment";
        NewerException: Record "Imported Adyen Payment";
        Payment: Record "Imported Adyen Payment";
    begin
        // Creation order differs from both PK directions and from lifecycle activity.
        InsertPayment(OlderException, 'SORT-EXCEPTION-Z-OLD', OlderDateTime(), OlderException.Status::Imported, 0);
        InsertPayment(Payment, 'SORT-EXCEPTION-A-MIDDLE', NewerDateTime(), Payment.Status::Error, 0);
        InsertPayment(NewerException, 'SORT-EXCEPTION-M-NEW', NewestDateTime(), NewerException.Status::ReversalRequired, 0);
        SetConflictingLifecycleDates(OlderException, NewerException);
        InsertPayment(Payment, 'SORT-EXCEPTION-B-BLANK', 0DT, Payment.Status::DataConflict, 0);
        InsertPayment(Payment, 'SORT-EXCEPTION-READY', NewestDateTime(), Payment.Status::ReadyToPost, 0);
        InsertPayment(Payment, 'SORT-EXCEPTION-DRAFT', NewestDateTime(), Payment.Status::ManualJournalCreated, 0);
        InsertPayment(Payment, 'SORT-EXCEPTION-POSTED', NewestDateTime(), Payment.Status::PostedApplied, 2147483602);

        InsertPayment(Payment, 'SORT-EXCEPTION-OTHER-MERCHANT', NewestDateTime(), Payment.Status::Error, 0);
        Payment.Rename('ZZZ-SORT-OTHER-MERCHANT', Payment."PSP Reference");
    end;

    local procedure AssertExceptionCreationOrder(var PaymentExceptions: TestPage "Adyen Payment Exceptions")
    begin
        AssertTrue(PaymentExceptions."Created At UTC".Visible(), 'Creation time must be visible on the exception page.');
        AssertTrue(PaymentExceptions.First(), 'The exception page must contain the newest created payment.');
        PaymentExceptions."PSP Reference".AssertEquals('SORT-EXCEPTION-M-NEW');
        PaymentExceptions."Created At UTC".AssertEquals(NewestDateTime());
        AssertTrue(PaymentExceptions.Next(), 'The exception page must contain the middle payment.');
        PaymentExceptions."PSP Reference".AssertEquals('SORT-EXCEPTION-A-MIDDLE');
        PaymentExceptions."Created At UTC".AssertEquals(NewerDateTime());
        AssertTrue(PaymentExceptions.Next(), 'The exception page must contain the oldest dated payment.');
        PaymentExceptions."PSP Reference".AssertEquals('SORT-EXCEPTION-Z-OLD');
        PaymentExceptions."Created At UTC".AssertEquals(OlderDateTime());
        AssertTrue(PaymentExceptions.Next(), 'A blank creation timestamp must follow dated payments.');
        PaymentExceptions."PSP Reference".AssertEquals('SORT-EXCEPTION-B-BLANK');
        PaymentExceptions."Created At UTC".AssertEquals(0DT);
        AssertTrue(not PaymentExceptions.Next(), 'The exception page must exclude ready, draft, posted, and other-merchant payments.');
    end;

    local procedure InsertWebhookRequest(var WebhookRequest: Record "Adyen Webhook Request"; ReceivedAt: DateTime; RequestStatus: Enum "Adyen Process Status")
    begin
        WebhookRequest.Init();
        WebhookRequest."Received At UTC" := ReceivedAt;
        WebhookRequest."Content Type" := 'application/json';
        WebhookRequest."Flow Run ID" := CopyStr(Format(CreateGuid()), 1, MaxStrLen(WebhookRequest."Flow Run ID"));
        WebhookRequest."Payload Hash" := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(WebhookRequest."Payload Hash"));
        WebhookRequest.Insert(true);
        WebhookRequest.Status := RequestStatus;
        WebhookRequest.Modify(false);
    end;

    local procedure InsertEvent(var EventEntry: Record "Adyen Event Entry"; MerchantAccount: Text[80]; PspReference: Text[50]; PaymentPspReference: Code[50]; OccurredAt: DateTime; EventStatus: Enum "Adyen Process Status")
    begin
        EventEntry.Init();
        EventEntry."Transport ID" := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(EventEntry."Transport ID"));
        EventEntry."Logical Event Key" := EventEntry."Transport ID";
        EventEntry.Source := EventEntry.Source::Webhook;
        EventEntry."Message Type" := 'AUTHORISATION';
        EventEntry."Merchant Account" := MerchantAccount;
        EventEntry."PSP Reference" := PspReference;
        EventEntry."Payment PSP Reference" := PaymentPspReference;
        EventEntry."Occurred At UTC" := OccurredAt;
        EventEntry.Status := EventStatus;
        EventEntry.Insert(true);
        EventEntry.Status := EventStatus;
        EventEntry.Modify(false);
    end;

    local procedure InsertPayment(var Payment: Record "Imported Adyen Payment"; PspReference: Code[50]; CreatedAt: DateTime; PaymentStatus: Enum "Adyen Payment Status"; PostedPaymentEntryNo: Integer)
    begin
        Payment.Init();
        Payment."Merchant Account" := SortMerchantAccount();
        Payment."PSP Reference" := PspReference;
        Payment."Event Date-Time" := CreatedAt;
        Payment."Latest Event At UTC" := CreatedAt;
        Payment.Status := PaymentStatus;
        Payment."Posted Payment Entry No." := PostedPaymentEntryNo;
        Payment.Insert(true);
        Payment."Created At UTC" := CreatedAt;
        Payment.Modify(false);
    end;

    local procedure InsertReportRun(var ReportRun: Record "Adyen Report Run"; ExternalReportId: Text[100]; RequestedAt: DateTime; ReportStatus: Enum "Adyen Report Run Status")
    begin
        ReportRun.Init();
        ReportRun."Merchant Account" := SortMerchantAccount();
        ReportRun."External Report ID" := ExternalReportId;
        ReportRun."Download URL" := 'https://example.test/' + ExternalReportId;
        ReportRun.Insert(true);
        ReportRun."Requested At UTC" := RequestedAt;
        ReportRun.Status := ReportStatus;
        ReportRun.Modify(false);
    end;

    local procedure SetConflictingLifecycleDates(var OlderPayment: Record "Imported Adyen Payment"; var NewerPayment: Record "Imported Adyen Payment")
    begin
        OlderPayment."Event Date-Time" := NewestDateTime();
        OlderPayment."Latest Event At UTC" := NewestDateTime();
        OlderPayment.Modify(false);
        NewerPayment."Event Date-Time" := OlderDateTime();
        NewerPayment."Latest Event At UTC" := OlderDateTime();
        NewerPayment.Modify(false);
    end;

    local procedure SetExpectedImportedPayments(NewerPayment: Record "Imported Adyen Payment"; OlderPayment: Record "Imported Adyen Payment")
    begin
        ExpectedFirstPaymentPspReference := NewerPayment."PSP Reference";
        ExpectedSecondPaymentPspReference := OlderPayment."PSP Reference";
        ExpectedFirstPaymentCreatedAt := NewerPayment."Created At UTC";
        ExpectedSecondPaymentCreatedAt := OlderPayment."Created At UTC";
    end;

    local procedure SortMerchantAccount(): Text[80]
    begin
        exit('ZZZ-SORT-TEST-MERCHANT');
    end;

    local procedure OlderDateTime(): DateTime
    begin
        exit(CreateDateTime(20991229D, 120000T));
    end;

    local procedure NewerDateTime(): DateTime
    begin
        exit(CreateDateTime(20991230D, 120000T));
    end;

    local procedure NewestDateTime(): DateTime
    begin
        exit(CreateDateTime(20991231D, 120000T));
    end;

    local procedure AssertTrue(Actual: Boolean; FailureMessage: Text)
    begin
        if not Actual then
            Error(FailureMessage);
    end;

    var
        ExpectedFirstEventPspReference: Text[50];
        ExpectedFirstPaymentPspReference: Text[50];
        ExpectedSecondEventPspReference: Text[50];
        ExpectedSecondPaymentPspReference: Text[50];
        ExpectedFirstPaymentCreatedAt: DateTime;
        ExpectedSecondPaymentCreatedAt: DateTime;
        ExpectedFirstReportId: Text[100];
        ExpectedSecondReportId: Text[100];
        ExpectedFirstWebhookEntryNo: BigInteger;
        ExpectedSecondWebhookEntryNo: BigInteger;
        ExpectedSourcePurged: Boolean;
}
