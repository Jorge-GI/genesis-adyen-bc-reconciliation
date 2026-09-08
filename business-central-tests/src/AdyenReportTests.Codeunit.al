codeunit 72154 "Adyen Report Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure MockedDownloadAndQuotedReorderedCsvBecomeReady()
    var
        EventEntry: Record "Adyen Event Entry";
        ReportRun: Record "Adyen Report Run";
        Downloader: Codeunit "Adyen Report Downloader";
        DownloadMock: Codeunit "Adyen Report Download Mock";
        Parser: Codeunit "Adyen Report Parser";
    begin
        ConfigureReportIntegration();
        InsertReportRun(ReportRun, 'payments_2026_09_03.csv');
        DownloadMock.ConfigureSuccess(ValidCsv());
        BindSubscription(DownloadMock);
        Downloader.Download(ReportRun);
        UnbindSubscription(DownloadMock);
        Parser.LoadRows(ReportRun);

        AssertTrue(ReportRun.Status = ReportRun.Status::Ready, 'A fully loaded report must become ready.');
        AssertEqualInteger(1, ReportRun."Relevant Row Count", 'The SentForSettle row must be relevant.');
        EventEntry.SetRange("Report Run Entry No.", ReportRun."Entry No.");
        AssertTrue(EventEntry.FindFirst(), 'The report row must be normalized.');
        AssertEqualText('ORDER,1', EventEntry."Merchant Reference", 'Quoted CSV values must retain embedded commas.');
        AssertEqualDecimal(123.45, EventEntry.Amount, 'Captured (PC) must be interpreted as a major-unit amount.');

        Parser.LoadRows(ReportRun);
        EventEntry.SetRange("Report Run Entry No.", ReportRun."Entry No.");
        AssertEqualInteger(1, EventEntry.Count(), 'Reprocessing the same report must be idempotent.');
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
            'ignored,SentForSettle,8831234567890124,ORDER-2,EUR,50.00,2026-09-03,CUST-2,WrongMerchant,scheme,');
        ReportRun.Status := ReportRun.Status::Loading;
        ReportRun.Modify(true);
        asserterror Parser.LoadRows(ReportRun);
        ReportRun.Get(ReportRun."Entry No.");
        AssertTrue(ReportRun.Status <> ReportRun.Status::Ready, 'A partially valid report must remain unavailable.');
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

    local procedure ValidCsv(): Text
    begin
        exit(
            'Extra,Record Type,PSP Reference,Merchant Reference,Payment Currency,Captured (PC),Booking Date,Shopper Reference,Merchant Account,Payment Method Variant,Modification PSP Reference' +
            LineBreak() +
            'ignored,SentForSettle,8831234567890123,"ORDER,1",EUR,123.45,2026-09-03,CUST-1,GenesisMerchant,scheme,');
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
