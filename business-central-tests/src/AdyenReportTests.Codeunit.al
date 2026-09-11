codeunit 72154 "Adyen Report Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure MockedDownloadAndQuotedReorderedCsvBecomeReady()
    var
        EventEntry: Record "Adyen Event Entry";
        ReportRun: Record "Adyen Report Run";
        DownloadMock: Codeunit "Adyen Report Download Mock";
        Parser: Codeunit "Adyen Report Parser";
        ReportWorker: Codeunit "Adyen Report Worker";
    begin
        ConfigureReportIntegration();
        InsertReportRun(ReportRun, 'payments_2026_09_03.csv');
        DownloadMock.ConfigureSuccess(ValidCsv());
        BindSubscription(DownloadMock);
        ReportWorker.Run(ReportRun);
        UnbindSubscription(DownloadMock);

        AssertTrue(ReportRun.Status = ReportRun.Status::Loading, 'A prepared report must remain in Loading until its rows are normalized.');
        AssertEqualInteger(1, ReportRun."Total Row Count", 'Preparation must count every data row.');
        AssertEqualInteger(1, ReportRun."Relevant Row Count", 'Preparation must count every relevant row.');
        AssertEqualInteger(0, ReportRun."Loaded Row Count", 'Preparation must not claim that uncommitted events are loaded.');
        EventEntry.SetRange("Report Run Entry No.", ReportRun."Entry No.");
        AssertEqualInteger(0, EventEntry.Count(), 'Preparation must not create report events.');

        ReportWorker.Run(ReportRun);

        AssertTrue(ReportRun.Status = ReportRun.Status::Ready, 'A fully loaded report must become ready.');
        AssertEqualInteger(1, ReportRun."Relevant Row Count", 'The SentForSettle row must be relevant.');
        EventEntry.SetRange("Report Run Entry No.", ReportRun."Entry No.");
        AssertTrue(EventEntry.FindFirst(), 'The report row must be normalized.');
        AssertEqualText('ORDER,1', EventEntry."Merchant Reference", 'Quoted CSV values must retain embedded commas.');
        AssertEqualDecimal(123.45, EventEntry.Amount, 'Captured (PC) must be interpreted as a major-unit amount.');
        AssertTrue(
            EventEntry."Occurred At UTC" = CreateDateTime(20260903D, 074811T),
            'A CET booking timestamp must be converted to UTC and the extra Booking Time value must be ignored.');

        Parser.LoadRows(ReportRun);
        EventEntry.SetRange("Report Run Entry No.", ReportRun."Entry No.");
        AssertEqualInteger(1, EventEntry.Count(), 'Reprocessing the same report must be idempotent.');
    end;

    [Test]
    procedure BookingTimeZonesConvertAcrossDateBoundaries()
    var
        EventEntry: Record "Adyen Event Entry";
        ReportRun: Record "Adyen Report Run";
        Parser: Codeunit "Adyen Report Parser";
    begin
        ConfigureReportIntegration();
        InsertReportRun(ReportRun, 'timezone_boundaries_2026_04_01.csv');
        SetReportContent(ReportRun, TimeZoneBoundaryCsv());
        ReportRun.Status := ReportRun.Status::Loading;
        ReportRun.Modify(true);

        Parser.LoadRows(ReportRun);

        AssertReportEventOccurredAt(
            EventEntry, ReportRun."Entry No.", 'TIMEZONE-CET', CreateDateTime(20251231D, 233000T),
            'CET conversion must cross the UTC year boundary correctly.');
        AssertReportEventOccurredAt(
            EventEntry, ReportRun."Entry No.", 'TIMEZONE-CEST', CreateDateTime(20260331D, 223000T),
            'CEST conversion must cross the UTC month boundary correctly.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure InvalidBookingDateKeepsPreparedCountsAndRetryRecalculatesThem()
    var
        EventEntry: Record "Adyen Event Entry";
        ReportRun: Record "Adyen Report Run";
        Dispatcher: Codeunit "Adyen Dispatcher";
        DownloadMock: Codeunit "Adyen Report Download Mock";
        ReportManagement: Codeunit "Adyen Report Management";
    begin
        ConfigureReportIntegration();
        InsertReportRun(ReportRun, 'booking_counts_2026_09_09.csv');
        DownloadMock.ConfigureSuccess(InvalidBookingDateCsv());
        BindSubscription(DownloadMock);

        Dispatcher.ProcessReport(ReportRun."Entry No.");

        UnbindSubscription(DownloadMock);
        ReportRun.Get(ReportRun."Entry No.");
        ReportRun.CalcFields(Content);
        AssertTrue(ReportRun.Status = ReportRun.Status::Error, 'An invalid relevant booking date must put the report in Error.');
        AssertEqualInteger(4, ReportRun."Total Row Count", 'The failed report must retain its complete data-row count.');
        AssertEqualInteger(3, ReportRun."Relevant Row Count", 'Relevant must include the invalid row and relevant rows after it.');
        AssertEqualInteger(0, ReportRun."Loaded Row Count", 'A rolled-back load must retain zero loaded rows.');
        AssertTrue(ReportRun."Report Date" = 20260909D, 'The report date resolved during preparation must survive the loading failure.');
        AssertEqualInteger(1, ReportRun."Retry Count", 'The failed loading phase must increment the retry count once.');
        AssertEqualText('Report row 3 has an invalid booking date.', ReportRun."Last Error", 'The existing booking-date error must be retained.');
        AssertTrue(ReportRun.Content.HasValue(), 'Prepared report content must survive a loading failure.');
        EventEntry.SetRange("Report Run Entry No.", ReportRun."Entry No.");
        AssertEqualInteger(0, EventEntry.Count(), 'A failed report load must not retain events from rows before the error.');

        ReportManagement.Retry(ReportRun);
        DownloadMock.ConfigureSuccess(CorrectedBookingDateCsv());
        BindSubscription(DownloadMock);

        Dispatcher.ProcessReport(ReportRun."Entry No.");

        UnbindSubscription(DownloadMock);
        ReportRun.Get(ReportRun."Entry No.");
        AssertTrue(ReportRun.Status = ReportRun.Status::Ready, 'A corrected retry must become ready.');
        AssertEqualInteger(2, ReportRun."Total Row Count", 'Retry preparation must replace the previous total count.');
        AssertEqualInteger(1, ReportRun."Relevant Row Count", 'An irrelevant row with an invalid date must remain outside the relevant count.');
        AssertEqualInteger(1, ReportRun."Loaded Row Count", 'Only the corrected relevant row must be loaded.');
        EventEntry.SetRange("Report Run Entry No.", ReportRun."Entry No.");
        AssertEqualInteger(1, EventEntry.Count(), 'The corrected retry must contain no partial events from the failed attempt.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    procedure TimeZoneValidationIsRowSpecificAndAtomic()
    var
        BlankTimeZoneReport: Record "Adyen Report Run";
        EventEntry: Record "Adyen Event Entry";
        UnsupportedTimeZoneReport: Record "Adyen Report Run";
        Dispatcher: Codeunit "Adyen Dispatcher";
        DownloadMock: Codeunit "Adyen Report Download Mock";
    begin
        ConfigureReportIntegration();
        InsertReportRun(UnsupportedTimeZoneReport, 'unsupported_timezone_2026_09_09.csv');
        DownloadMock.ConfigureSuccess(UnsupportedTimeZoneCsv());
        BindSubscription(DownloadMock);

        Dispatcher.ProcessReport(UnsupportedTimeZoneReport."Entry No.");

        UnbindSubscription(DownloadMock);
        UnsupportedTimeZoneReport.Get(UnsupportedTimeZoneReport."Entry No.");
        AssertTrue(UnsupportedTimeZoneReport.Status = UnsupportedTimeZoneReport.Status::Error, 'An unsupported time zone must put the report in Error.');
        AssertEqualInteger(2, UnsupportedTimeZoneReport."Total Row Count", 'Preparation must retain the complete row count before time-zone validation.');
        AssertEqualInteger(2, UnsupportedTimeZoneReport."Relevant Row Count", 'Both supported record types must be counted before time-zone validation.');
        AssertEqualInteger(0, UnsupportedTimeZoneReport."Loaded Row Count", 'An unsupported time zone must roll back every event in the loading phase.');
        AssertEqualText('Report row 3 has unsupported TimeZone PST.', UnsupportedTimeZoneReport."Last Error", 'The unsupported time-zone error must identify the source row and value.');
        EventEntry.SetRange("Report Run Entry No.", UnsupportedTimeZoneReport."Entry No.");
        AssertEqualInteger(0, EventEntry.Count(), 'A valid row before an unsupported time zone must not survive the failed atomic load.');

        InsertReportRun(BlankTimeZoneReport, 'blank_timezone_2026_09_10.csv');
        DownloadMock.ConfigureSuccess(BlankTimeZoneCsv());
        BindSubscription(DownloadMock);

        Dispatcher.ProcessReport(BlankTimeZoneReport."Entry No.");

        UnbindSubscription(DownloadMock);
        BlankTimeZoneReport.Get(BlankTimeZoneReport."Entry No.");
        AssertTrue(BlankTimeZoneReport.Status = BlankTimeZoneReport.Status::Error, 'A blank time zone must put the report in Error.');
        AssertEqualInteger(1, BlankTimeZoneReport."Relevant Row Count", 'Preparation must count a relevant row before validating its blank time zone.');
        AssertEqualInteger(0, BlankTimeZoneReport."Loaded Row Count", 'A blank time zone must leave the committed loaded count at zero.');
        AssertEqualText('Report row 2 has no TimeZone.', BlankTimeZoneReport."Last Error", 'The blank time-zone error must identify the source row.');
        EventEntry.Reset();
        EventEntry.SetRange("Report Run Entry No.", BlankTimeZoneReport."Entry No.");
        AssertEqualInteger(0, EventEntry.Count(), 'A report with a blank time zone must not retain any events.');
    end;

    [Test]
    procedure CancelledAndExpiredRowsAreLoadedAsRelevantEvents()
    var
        EventEntry: Record "Adyen Event Entry";
        ReportRun: Record "Adyen Report Run";
        Parser: Codeunit "Adyen Report Parser";
    begin
        ConfigureReportIntegration();
        InsertReportRun(ReportRun, 'payments_2026_09_04.csv');
        SetReportContent(ReportRun, CancellationAndExpiryCsv());
        ReportRun.Status := ReportRun.Status::Loading;
        ReportRun.Modify(true);

        Parser.LoadRows(ReportRun);

        AssertTrue(ReportRun.Status = ReportRun.Status::Ready, 'A report containing cancellation and expiry rows must become ready.');
        AssertEqualInteger(2, ReportRun."Relevant Row Count", 'Cancelled and Expired rows must both be relevant.');
        AssertEqualInteger(2, ReportRun."Loaded Row Count", 'Cancelled and Expired rows must both be normalized.');
        EventEntry.SetRange("Report Run Entry No.", ReportRun."Entry No.");
        EventEntry.SetRange("Message Type", 'Cancelled');
        AssertEqualInteger(1, EventEntry.Count(), 'The Cancelled row must be retained as an event.');
        EventEntry.SetRange("Message Type", 'Expired');
        AssertEqualInteger(1, EventEntry.Count(), 'The Expired row must be retained as an event.');
    end;

    [Test]
    procedure AuthorisedSentForSettleAndSettledRowsUseLifecycleAmounts()
    var
        EventEntry: Record "Adyen Event Entry";
        ReportRun: Record "Adyen Report Run";
        Parser: Codeunit "Adyen Report Parser";
    begin
        ConfigureReportIntegration();
        InsertReportRun(ReportRun, 'payments_2026_09_05.csv');
        SetReportContent(ReportRun, NormalLifecycleCsv());
        ReportRun.Status := ReportRun.Status::Loading;
        ReportRun.Modify(true);

        Parser.LoadRows(ReportRun);

        AssertEqualInteger(3, ReportRun."Relevant Row Count", 'All three normal lifecycle rows must be relevant.');
        AssertLifecycleReportEvent(EventEntry, ReportRun."Entry No.", 'Authorised', 125, 'The Authorised row must use Authorised (PC).');
        AssertLifecycleReportEvent(EventEntry, ReportRun."Entry No.", 'SentForSettle', 125, 'The SentForSettle row must use Captured (PC).');
        AssertLifecycleReportEvent(EventEntry, ReportRun."Entry No.", 'Settled', 125, 'The Settled row must use Captured (PC).');
    end;

    [Test]
    procedure AuthorisationSideRowHashesUseSignedAuthorisedAmount()
    begin
        ConfigureReportIntegration();
        AssertAuthoritativeAmountIdentity('Authorised', true);
        AssertAuthoritativeAmountIdentity('Cancelled', true);
        AssertAuthoritativeAmountIdentity('Expired', true);
    end;

    [Test]
    procedure CaptureSideRowHashesUseSignedCapturedAmount()
    begin
        ConfigureReportIntegration();
        AssertAuthoritativeAmountIdentity('SentForSettle', false);
        AssertAuthoritativeAmountIdentity('Settled', false);
        AssertAuthoritativeAmountIdentity('Refunded', false);
    end;

    [Test]
    procedure IntermediateRefundRowsRemainOutsideRelevantReportEvents()
    var
        EventEntry: Record "Adyen Event Entry";
        ReportRun: Record "Adyen Report Run";
        Parser: Codeunit "Adyen Report Parser";
    begin
        ConfigureReportIntegration();
        InsertReportRun(ReportRun, 'payments_2026_09_07.csv');
        SetReportContent(ReportRun, IntermediateRefundCsv());
        ReportRun.Status := ReportRun.Status::Loading;
        ReportRun.Modify(true);

        Parser.LoadRows(ReportRun);

        AssertTrue(ReportRun.Status = ReportRun.Status::Ready, 'Unsupported intermediate rows must not prevent the report becoming ready.');
        AssertEqualInteger(0, ReportRun."Relevant Row Count", 'SentForRefund and RefundAuthorised must stay outside relevant report events.');
        EventEntry.SetRange("Report Run Entry No.", ReportRun."Entry No.");
        AssertEqualInteger(0, EventEntry.Count(), 'Unsupported intermediate PAR rows must not be normalized into Event Entries.');
    end;

    [Test]
    procedure MockedHttpFailureIsSurfaced()
    var
        ReportRun: Record "Adyen Report Run";
        Downloader: Codeunit "Adyen Report Downloader";
        DownloadMock: Codeunit "Adyen Report Download Mock";
    begin
        ConfigureReportIntegration();
        InsertReportRun(ReportRun, 'payments_2026_09_03.csv');
        DownloadMock.ConfigureFailure();
        BindSubscription(DownloadMock);
        asserterror Downloader.Download(ReportRun);
        UnbindSubscription(DownloadMock);
    end;

    [Test]
    procedure DownloadUrlMustBeHttpsAndAllowlisted()
    var
        Downloader: Codeunit "Adyen Report Downloader";
    begin
        Downloader.ValidateDownloadUrl('https://ca-test.adyen.com/reports/a.csv', 'ca-test.adyen.com');
        Downloader.ValidateDownloadUrl('https://reports.ca-test.adyen.com/reports/a.csv', 'ca-test.adyen.com');
        asserterror Downloader.ValidateDownloadUrl('http://ca-test.adyen.com/reports/a.csv', 'ca-test.adyen.com');
        asserterror Downloader.ValidateDownloadUrl('https://ca-test.adyen.com:8443/reports/a.csv', 'ca-test.adyen.com');
        asserterror Downloader.ValidateDownloadUrl('https://ca-test.adyen.com.evil.example/reports/a.csv', 'ca-test.adyen.com');
    end;

    [Test]
    procedure MockedFileSizeLimitIsEnforced()
    var
        ReportRun: Record "Adyen Report Run";
        Setup: Record "Adyen Setup";
        Downloader: Codeunit "Adyen Report Downloader";
        DownloadMock: Codeunit "Adyen Report Download Mock";
    begin
        ConfigureReportIntegration();
        Setup.Get('SETUP');
        Setup."Max Report File Bytes" := 1024;
        Setup.Modify(true);
        InsertReportRun(ReportRun, 'payments_2026_09_03.csv');
        DownloadMock.ConfigureSuccess(PadStr('', 1500, 'x'));
        BindSubscription(DownloadMock);
        asserterror Downloader.Download(ReportRun);
        UnbindSubscription(DownloadMock);
    end;

    [Test]
    procedure ShortResponseCanBeCopiedWithLargeConfiguredLimit()
    var
        Downloader: Codeunit "Adyen Report Downloader";
        SourceBlob: Codeunit "Temp Blob";
        TargetBlob: Codeunit "Temp Blob";
        SourceInStream: InStream;
        Content: Text;
    begin
        Content := PadStr('', 885, 'x');
        WriteBlob(SourceBlob, Content);
        SourceBlob.CreateInStream(SourceInStream);

        Downloader.CopyResponseToTempBlob(SourceInStream, 50000000, TargetBlob);

        AssertTrue(TargetBlob.Length() = 885, 'A short response must be copied without requesting the configured maximum length.');
        AssertBlobText(TargetBlob, Content, 'The copied short response must remain unchanged.');
    end;

    [Test]
    procedure ResponseAtConfiguredLimitIsAccepted()
    var
        Downloader: Codeunit "Adyen Report Downloader";
        SourceBlob: Codeunit "Temp Blob";
        TargetBlob: Codeunit "Temp Blob";
        SourceInStream: InStream;
        Content: Text;
    begin
        Content := PadStr('', 1024, 'x');
        WriteBlob(SourceBlob, Content);
        SourceBlob.CreateInStream(SourceInStream);

        Downloader.CopyResponseToTempBlob(SourceInStream, 1024, TargetBlob);

        AssertTrue(TargetBlob.Length() = 1024, 'A response exactly at the configured limit must be accepted.');
        AssertBlobText(TargetBlob, Content, 'The response at the configured limit must remain unchanged.');
    end;

    [Test]
    procedure ResponseOverConfiguredLimitIsRejectedBeforeStorage()
    var
        Downloader: Codeunit "Adyen Report Downloader";
        SourceBlob: Codeunit "Temp Blob";
        TargetBlob: Codeunit "Temp Blob";
        SourceInStream: InStream;
    begin
        WriteBlob(SourceBlob, PadStr('', 1025, 'x'));
        SourceBlob.CreateInStream(SourceInStream);

        asserterror Downloader.CopyResponseToTempBlob(SourceInStream, 1024, TargetBlob);

        AssertEqualText(StrSubstNo('The report exceeds the configured maximum of %1 bytes.', 1024), GetLastErrorText(), 'An oversized response must return the configured size error.');
        AssertTrue(TargetBlob.Length() = 0, 'A response with a known oversized length must be rejected before storage.');
    end;

    [Test]
    procedure EmptyDownloadedReportIsRejected()
    var
        ReportRun: Record "Adyen Report Run";
        Downloader: Codeunit "Adyen Report Downloader";
        DownloadMock: Codeunit "Adyen Report Download Mock";
    begin
        ConfigureReportIntegration();
        InsertReportRun(ReportRun, 'payments_2026_09_03.csv');
        DownloadMock.ConfigureSuccess('');
        BindSubscription(DownloadMock);
        asserterror Downloader.Download(ReportRun);
        UnbindSubscription(DownloadMock);

        AssertEqualText('The downloaded report is empty.', GetLastErrorText(), 'An empty response must retain the existing validation error.');
    end;

    [Test]
    procedure PurgedErroredReportCanBeQueuedAndRehydrated()
    var
        ReportRun: Record "Adyen Report Run";
        Downloader: Codeunit "Adyen Report Downloader";
        DownloadMock: Codeunit "Adyen Report Download Mock";
        Parser: Codeunit "Adyen Report Parser";
        ReportManagement: Codeunit "Adyen Report Management";
        Retention: Codeunit "Adyen Retention";
    begin
        ConfigureReportIntegration();
        InsertReportRun(ReportRun, 'payments_2099_09_03.csv');
        ReportRun.Status := ReportRun.Status::Error;
        ReportRun."Content Purged" := true;
        ReportRun."Last Error" := 'Previous download failed.';
        ReportRun.Modify(true);

        ReportManagement.Retry(ReportRun);

        AssertTrue(ReportRun.Status = ReportRun.Status::Requested, 'Retry must queue the report for background download.');
        AssertTrue(ReportRun."Content Purged", 'The report remains purged until a download succeeds.');
        AssertEqualText('', ReportRun."Last Error", 'Retry must clear the previous error.');

        DownloadMock.ConfigureSuccess(ValidCsv());
        BindSubscription(DownloadMock);
        Downloader.Download(ReportRun);
        UnbindSubscription(DownloadMock);

        AssertTrue(not ReportRun."Content Purged", 'A successful re-download must clear the purged flag.');
        AssertTrue(ReportRun.Status = ReportRun.Status::Loading, 'A re-downloaded report must continue to loading.');

        Parser.LoadRows(ReportRun);
        Retention.RunCleanup();

        ReportRun.Get(ReportRun."Entry No.");
        ReportRun.CalcFields(Content);
        AssertTrue(ReportRun.Content.HasValue(), 'Retention must keep newly downloaded content whose report date is within the retention period.');
        AssertTrue(not ReportRun."Content Purged", 'A retained retry download must not be marked as purged.');
    end;

    [Test]
    procedure QueueingRetryDoesNotDeleteRetainedContent()
    var
        ReportRun: Record "Adyen Report Run";
        ReportManagement: Codeunit "Adyen Report Management";
    begin
        ConfigureReportIntegration();
        InsertReportRun(ReportRun, 'payments_2026_09_03.csv');
        SetReportContent(ReportRun, ValidCsv());
        ReportRun.Status := ReportRun.Status::Error;
        ReportRun."Last Error" := 'Previous load failed.';
        ReportRun.Modify(true);

        ReportManagement.Retry(ReportRun);

        ReportRun.Get(ReportRun."Entry No.");
        ReportRun.CalcFields(Content);
        AssertTrue(ReportRun.Content.HasValue(), 'Queueing a retry must not delete retained report content.');
        AssertTrue(not ReportRun."Content Purged", 'Queueing a retry must not mark retained content as purged.');
    end;

    [Test]
    procedure FilenameMustContainExactlyOneReportDate()
    var
        Parser: Codeunit "Adyen Report Parser";
    begin
        AssertTrue(Parser.ResolveReportDate('payments_2026_09_03.csv') = 20260903D, 'The report date was not resolved.');
        asserterror Parser.ResolveReportDate('payments.csv');
        asserterror Parser.ResolveReportDate('2026_09_03_to_2026_09_04.csv');
    end;

    [Test]
    procedure MalformedAndPartiallyLoadedReportsNeverBecomeReady()
    var
        ReportRun: Record "Adyen Report Run";
        Parser: Codeunit "Adyen Report Parser";
    begin
        ConfigureReportIntegration();
        InsertReportRun(ReportRun, 'payments_2026_09_03.csv');
        SetReportContent(ReportRun, 'Merchant Account,PSP Reference' + LineBreak() + 'GenesisMerchant,PSP-1');
        ReportRun.Status := ReportRun.Status::Loading;
        ReportRun.Modify(true);
        asserterror Parser.LoadRows(ReportRun);
        ReportRun.Get(ReportRun."Entry No.");
        AssertTrue(ReportRun.Status <> ReportRun.Status::Ready, 'A malformed report must not become ready.');

        SetReportContent(ReportRun, ValidCsv() + LineBreak() +
            'ignored,SentForSettle,8831234567890124,ORDER-2,EUR,0.00,50.00,2026-09-03 12:00:00,CET,ignored,CUST-2,WrongMerchant,scheme,');
        ReportRun.Status := ReportRun.Status::Loading;
        ReportRun.Modify(true);
        asserterror Parser.LoadRows(ReportRun);
        ReportRun.Get(ReportRun."Entry No.");
        AssertTrue(ReportRun.Status <> ReportRun.Status::Ready, 'A partially valid report must remain unavailable.');
    end;

    [Test]
    procedure MissingTimeZoneHeaderUsesRequiredColumnValidation()
    var
        ReportRun: Record "Adyen Report Run";
        Parser: Codeunit "Adyen Report Parser";
    begin
        ConfigureReportIntegration();
        InsertReportRun(ReportRun, 'missing_timezone_2026_09_03.csv');
        SetReportContent(ReportRun, MissingTimeZoneCsv());

        asserterror Parser.PrepareRows(ReportRun);

        AssertEqualText(
            'The Adyen report is missing required column timezone.', GetLastErrorText(),
            'Normal report preparation must require the official TimeZone header.');
    end;

    [Test]
    procedure DateOnlyBookingDateUsesNormalBookingDateValidation()
    var
        ReportRun: Record "Adyen Report Run";
        Parser: Codeunit "Adyen Report Parser";
    begin
        ConfigureReportIntegration();
        InsertReportRun(ReportRun, 'date_only_2026_09_03.csv');
        SetReportContent(ReportRun, DateOnlyWithTimeZoneCsv());
        ReportRun.Status := ReportRun.Status::Loading;
        ReportRun.Modify(true);

        asserterror Parser.LoadRows(ReportRun);

        AssertEqualText(
            'Report row 2 has an invalid booking date.', GetLastErrorText(),
            'A date-only value must fail booking-date validation even when a separate Booking Time column is present.');
    end;

    local procedure AssertAuthoritativeAmountIdentity(RecordType: Text; UsesAuthorisedAmount: Boolean)
    var
        BaseEvent: Record "Adyen Event Entry";
        ChangedEvent: Record "Adyen Event Entry";
        PositiveEvent: Record "Adyen Event Entry";
        NormalizedEvent: Record "Adyen Event Entry";
        OtherColumnEvent: Record "Adyen Event Entry";
    begin
        if UsesAuthorisedAmount then begin
            LoadAmountIdentityEvent(BaseEvent, RecordType, 'base', '-125.00', '');
            LoadAmountIdentityEvent(ChangedEvent, RecordType, 'changed', '-126.00', '');
            LoadAmountIdentityEvent(PositiveEvent, RecordType, 'positive', '125.00', '');
            LoadAmountIdentityEvent(NormalizedEvent, RecordType, 'normalized', '-125.0', '');
            LoadAmountIdentityEvent(OtherColumnEvent, RecordType, 'other', '-125.00', 'not-a-number');
        end else begin
            LoadAmountIdentityEvent(BaseEvent, RecordType, 'base', '', '-125.00');
            LoadAmountIdentityEvent(ChangedEvent, RecordType, 'changed', '', '-126.00');
            LoadAmountIdentityEvent(PositiveEvent, RecordType, 'positive', '', '125.00');
            LoadAmountIdentityEvent(NormalizedEvent, RecordType, 'normalized', '', '-125.0');
            LoadAmountIdentityEvent(OtherColumnEvent, RecordType, 'other', 'not-a-number', '-125.00');
        end;

        AssertTrue(BaseEvent."Report Row Identity" <> ChangedEvent."Report Row Identity", 'Changing the authoritative amount must change the row identity.');
        AssertTrue(BaseEvent."Report Row Identity" <> PositiveEvent."Report Row Identity", 'The source amount sign must be retained in the row identity.');
        AssertEqualText(BaseEvent."Report Row Identity", NormalizedEvent."Report Row Identity", 'Equivalent decimal representations must have the same normalized row identity.');
        AssertEqualText(BaseEvent."Report Row Identity", OtherColumnEvent."Report Row Identity", 'The unused amount column must not affect the row identity or require a valid value.');
        AssertEqualDecimal(125, BaseEvent.Amount, 'A negative source amount must be stored as an absolute payment amount.');
        AssertEqualDecimal(125, PositiveEvent.Amount, 'A positive source amount must retain the same absolute payment amount.');
        AssertEqualDecimal(126, ChangedEvent.Amount, 'The event must use the changed authoritative amount.');
    end;

    local procedure LoadAmountIdentityEvent(var EventEntry: Record "Adyen Event Entry"; RecordType: Text; Suffix: Text; AuthorisedText: Text; CapturedText: Text)
    var
        ReportRun: Record "Adyen Report Run";
        Crypto: Codeunit "Adyen Cryptography";
        Parser: Codeunit "Adyen Report Parser";
        Content: Text;
        TransportId: Code[64];
    begin
        InsertReportRun(ReportRun, LowerCase(RecordType) + '_' + Suffix + '_2026_09_05.csv');
        Content := OfficialReportHeader() + LineBreak() +
            'ignored,' + RecordType + ',HASH-PSP,HASH-ORDER,EUR,' + AuthorisedText + ',' + CapturedText +
            ',2026-09-05 09:00:00,CEST,HASH-CUST,GenesisMerchant,scheme,';
        SetReportContent(ReportRun, Content);
        ReportRun."File Hash" := Crypto.GenerateSha256(Content);
        ReportRun.Status := ReportRun.Status::Loading;
        ReportRun.Modify(true);

        Parser.LoadRows(ReportRun);

        EventEntry.SetRange("Report Run Entry No.", ReportRun."Entry No.");
        AssertTrue(EventEntry.FindFirst(), 'The amount-identity fixture must load one report event.');
        TransportId := EventEntry."Transport ID";
        Parser.LoadRows(ReportRun);
        AssertEqualInteger(1, EventEntry.Count(), 'Loading the same report again must not duplicate its event.');
        AssertEqualInteger(1, ReportRun."Loaded Row Count", 'An idempotent reload must still count the loaded row.');
        AssertTrue(EventEntry.FindFirst(), 'The event must remain available after reloading.');
        AssertEqualText(TransportId, EventEntry."Transport ID", 'An idempotent reload must preserve the transport identity.');
        AssertEqualText('HASH-PSP', EventEntry."Payment PSP Reference", 'Fresh report rows must initialize their payment reference.');
    end;

    local procedure ConfigureReportIntegration()
    var
        Merchant: Record "Adyen Merchant";
        Setup: Record "Adyen Setup";
        Credentials: Codeunit "Adyen Credentials";
    begin
        Setup.GetRecordOnce();
        Setup.Enabled := true;
        Setup.Environment := Setup.Environment::Test;
        Setup."Allowed Report Hosts" := 'ca-test.adyen.com';
        Setup."Max Report File Bytes" := 52428800;
        Setup.Modify(true);
        Credentials.SetCurrentHmacHex('00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff');
        Credentials.SetReportCredentials('report-user', 'report-password');

        if Merchant.Get('GenesisMerchant') then
            Merchant.Delete(true);
        Merchant.Init();
        Merchant."Merchant Account" := 'GenesisMerchant';
        Merchant.Enabled := true;
        Merchant.Insert(true);
    end;

    local procedure InsertReportRun(var ReportRun: Record "Adyen Report Run"; ExternalReportId: Text)
    begin
        ReportRun.Init();
        ReportRun."Merchant Account" := 'GenesisMerchant';
        ReportRun."External Report ID" := ExternalReportId;
        ReportRun."Download URL" := 'https://ca-test.adyen.com/reports/' + ExternalReportId;
        ReportRun.Insert(true);
    end;

    local procedure SetReportContent(var ReportRun: Record "Adyen Report Run"; Content: Text)
    var
        ReportOutStream: OutStream;
    begin
        ReportRun.Content.CreateOutStream(ReportOutStream, TextEncoding::UTF8);
        ReportOutStream.WriteText(Content);
    end;

    local procedure WriteBlob(var TempBlob: Codeunit "Temp Blob"; Content: Text)
    var
        ContentOutStream: OutStream;
    begin
        TempBlob.CreateOutStream(ContentOutStream);
        ContentOutStream.WriteText(Content);
    end;

    local procedure AssertBlobText(var TempBlob: Codeunit "Temp Blob"; Expected: Text; FailureMessage: Text)
    var
        ContentInStream: InStream;
        Actual: Text;
    begin
        TempBlob.CreateInStream(ContentInStream);
        ContentInStream.ReadText(Actual);
        AssertEqualText(Expected, Actual, FailureMessage);
    end;

    local procedure ValidCsv(): Text
    begin
        exit(
            OfficialReportHeaderWithBookingTime() +
            LineBreak() +
            'ignored,SentForSettle,8831234567890123,"ORDER,1",EUR,0.00,123.45," 2026-09-03 08:48:11 "," cet ",not-a-time,CUST-1,GenesisMerchant,scheme,');
    end;

    local procedure InvalidBookingDateCsv(): Text
    begin
        exit(
            OfficialReportHeader() +
            LineBreak() +
            'ignored,SentForSettle,PREPARED-PSP-1,PREPARED-ORDER-1,EUR,0.00,10.00,2026-09-09 08:40:00,CET,PREPARED-CUST-1,GenesisMerchant,scheme,' +
            LineBreak() +
            'ignored,SentForSettle,PREPARED-PSP-2,PREPARED-ORDER-2,EUR,0.00,20.00,2026-09-09 08:48,CET,PREPARED-CUST-2,GenesisMerchant,scheme,' +
            LineBreak() +
            'ignored,SentForRefund,PREPARED-PSP-3,PREPARED-ORDER-3,EUR,30.00,30.00,also-not-a-date,PST,PREPARED-CUST-3,GenesisMerchant,scheme,' +
            LineBreak() +
            'ignored,Settled,PREPARED-PSP-4,PREPARED-ORDER-4,EUR,40.00,40.00,2026-09-09 09:00:00,CEST,PREPARED-CUST-4,GenesisMerchant,scheme,');
    end;

    local procedure CorrectedBookingDateCsv(): Text
    begin
        exit(
            OfficialReportHeader() +
            LineBreak() +
            'ignored,SentForRefund,CORRECTED-PSP-1,CORRECTED-ORDER-1,EUR,50.00,50.00,still-not-a-date,PST,CORRECTED-CUST-1,GenesisMerchant,scheme,' +
            LineBreak() +
            'ignored,Settled,CORRECTED-PSP-2,CORRECTED-ORDER-2,EUR,60.00,60.00,2026-09-09 10:00:00,CET,CORRECTED-CUST-2,GenesisMerchant,scheme,');
    end;

    local procedure CancellationAndExpiryCsv(): Text
    begin
        exit(
            OfficialReportHeader() +
            LineBreak() +
            'ignored,Cancelled,8831234567890123,ORDER-1,EUR,-123.45,,2026-09-04 09:00:00,CEST,CUST-1,GenesisMerchant,scheme,9911234567890123' +
            LineBreak() +
            'ignored,Expired,8831234567890124,ORDER-2,EUR,-50.00,,2026-09-04 10:00:00,CEST,CUST-2,GenesisMerchant,scheme,');
    end;

    local procedure NormalLifecycleCsv(): Text
    begin
        exit(
            OfficialReportHeader() +
            LineBreak() +
            'ignored,Authorised,8831234567890999,ORDER-9,EUR,-125.00,,2026-09-05 09:00:00,CEST,CUST-9,GenesisMerchant,scheme,' +
            LineBreak() +
            'ignored,SentForSettle,8831234567890999,ORDER-9,EUR,-125.00,-125.00,2026-09-05 10:00:00,CEST,CUST-9,GenesisMerchant,scheme,' +
            LineBreak() +
            'ignored,Settled,8831234567890999,ORDER-9,EUR,-125.00,-125.00,2026-09-05 11:00:00,CEST,CUST-9,GenesisMerchant,scheme,');
    end;

    local procedure IntermediateRefundCsv(): Text
    begin
        exit(
            OfficialReportHeader() +
            LineBreak() +
            'ignored,SentForRefund,8831234567890777,ORDER-7,EUR,100.00,100.00,not-a-date,PST,CUST-7,GenesisMerchant,scheme,9911234567890777' +
            LineBreak() +
            'ignored,RefundAuthorised,8831234567890888,ORDER-8,EUR,100.00,100.00,also-not-a-date,,CUST-8,GenesisMerchant,scheme,');
    end;

    local procedure TimeZoneBoundaryCsv(): Text
    begin
        exit(
            OfficialReportHeader() +
            LineBreak() +
            'ignored,SentForSettle,TIMEZONE-CET,TIMEZONE-ORDER-1,EUR,0.00,10.00,2026-01-01 00:30:00,CET,TIMEZONE-CUST-1,GenesisMerchant,scheme,' +
            LineBreak() +
            'ignored,SentForSettle,TIMEZONE-CEST,TIMEZONE-ORDER-2,EUR,0.00,20.00,2026-04-01 00:30:00,CEST,TIMEZONE-CUST-2,GenesisMerchant,scheme,');
    end;

    local procedure UnsupportedTimeZoneCsv(): Text
    begin
        exit(
            OfficialReportHeader() +
            LineBreak() +
            'ignored,SentForSettle,TIMEZONE-VALID,TIMEZONE-ORDER-1,EUR,0.00,10.00,2026-09-09 09:00:00,CET,TIMEZONE-CUST-1,GenesisMerchant,scheme,' +
            LineBreak() +
            'ignored,Settled,TIMEZONE-UNSUPPORTED,TIMEZONE-ORDER-2,EUR,0.00,20.00,2026-09-09 10:00:00,PST,TIMEZONE-CUST-2,GenesisMerchant,scheme,');
    end;

    local procedure BlankTimeZoneCsv(): Text
    begin
        exit(
            OfficialReportHeader() +
            LineBreak() +
            'ignored,Settled,TIMEZONE-BLANK,TIMEZONE-ORDER-3,EUR,0.00,30.00,2026-09-10 10:00:00,,TIMEZONE-CUST-3,GenesisMerchant,scheme,');
    end;

    local procedure DateOnlyWithTimeZoneCsv(): Text
    begin
        exit(
            OfficialReportHeaderWithBookingTime() +
            LineBreak() +
            'ignored,Settled,LEGACY-DATE,LEGACY-ORDER,EUR,0.00,10.00,2026-09-03,CET,10:00:00,LEGACY-CUST,GenesisMerchant,scheme,');
    end;

    local procedure MissingTimeZoneCsv(): Text
    begin
        exit(
            'Extra,Record Type,PSP Reference,Merchant Reference,Payment Currency,Authorised (PC),Captured (PC),Booking Date,Booking Time,Shopper Reference,Merchant Account,Payment Method Variant,Modification PSP Reference' +
            LineBreak() +
            'ignored,Authorised,MISSING-ZONE,MISSING-ZONE-ORDER,EUR,-10.00,,2026-09-08,09:00:00,MISSING-ZONE-CUST,GenesisMerchant,scheme,');
    end;

    local procedure OfficialReportHeader(): Text
    begin
        exit('Extra,Record Type,PSP Reference,Merchant Reference,Payment Currency,Authorised (PC),Captured (PC),Booking Date,TimeZone,Shopper Reference,Merchant Account,Payment Method Variant,Modification PSP Reference');
    end;

    local procedure OfficialReportHeaderWithBookingTime(): Text
    begin
        exit('Extra,Record Type,PSP Reference,Merchant Reference,Payment Currency,Authorised (PC),Captured (PC),Booking Date,TimeZone,Booking Time,Shopper Reference,Merchant Account,Payment Method Variant,Modification PSP Reference');
    end;

    local procedure AssertLifecycleReportEvent(var EventEntry: Record "Adyen Event Entry"; ReportRunEntryNo: BigInteger; MessageType: Text; ExpectedAmount: Decimal; FailureMessage: Text)
    begin
        EventEntry.Reset();
        EventEntry.SetRange("Report Run Entry No.", ReportRunEntryNo);
        EventEntry.SetRange("Message Type", MessageType);
        AssertTrue(EventEntry.FindFirst(), StrSubstNo('%1 event must be loaded.', MessageType));
        AssertEqualDecimal(ExpectedAmount, EventEntry.Amount, FailureMessage);
        AssertEqualText('8831234567890999', EventEntry."Payment PSP Reference", 'The event must carry the normalized payment PSP reference.');
    end;

    local procedure AssertReportEventOccurredAt(var EventEntry: Record "Adyen Event Entry"; ReportRunEntryNo: BigInteger; PaymentPspReference: Text; Expected: DateTime; FailureMessage: Text)
    begin
        EventEntry.Reset();
        EventEntry.SetRange("Report Run Entry No.", ReportRunEntryNo);
        EventEntry.SetRange("Payment PSP Reference", PaymentPspReference);
        AssertTrue(EventEntry.FindFirst(), StrSubstNo('Report event %1 must be loaded.', PaymentPspReference));
        AssertTrue(EventEntry."Occurred At UTC" = Expected, FailureMessage);
    end;

    local procedure LineBreak(): Text
    var
        NewLine: Char;
    begin
        NewLine := 10;
        exit(Format(NewLine));
    end;

    local procedure AssertTrue(Actual: Boolean; FailureMessage: Text)
    begin
        if not Actual then
            Error(FailureMessage);
    end;

    local procedure AssertFalse(Actual: Boolean; FailureMessage: Text)
    begin
        if Actual then
            Error(FailureMessage);
    end;

    local procedure AssertEqualInteger(Expected: Integer; Actual: Integer; FailureMessage: Text)
    begin
        if Expected <> Actual then
            Error('%1 Expected %2, actual %3.', FailureMessage, Expected, Actual);
    end;

    local procedure AssertEqualDecimal(Expected: Decimal; Actual: Decimal; FailureMessage: Text)
    begin
        if Expected <> Actual then
            Error('%1 Expected %2, actual %3.', FailureMessage, Expected, Actual);
    end;

    local procedure AssertEqualText(Expected: Text; Actual: Text; FailureMessage: Text)
    begin
        if Expected <> Actual then
            Error('%1 Expected %2, actual %3.', FailureMessage, Expected, Actual);
    end;
}
