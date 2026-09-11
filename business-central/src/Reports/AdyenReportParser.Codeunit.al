codeunit 72041 "Adyen Report Parser"
{
    internal procedure PrepareRows(var ReportRun: Record "Adyen Report Run")
    var
        TempCSVBuffer: Record "CSV Buffer" temporary;
        HeaderMap: Dictionary of [Text, Integer];
        LastLineNo: Integer;
    begin
        ReadReport(ReportRun, TempCSVBuffer, HeaderMap, LastLineNo);
        CalculateRowCounts(TempCSVBuffer, HeaderMap, LastLineNo, ReportRun);
        ReportRun.Modify(true);
    end;

    procedure LoadRows(var ReportRun: Record "Adyen Report Run")
    var
        Merchant: Record "Adyen Merchant";
        TempCSVBuffer: Record "CSV Buffer" temporary;
        HeaderMap: Dictionary of [Text, Integer];
        LineNo: Integer;
        LastLineNo: Integer;
        LoadedCount: Integer;
    begin
        ReadReport(ReportRun, TempCSVBuffer, HeaderMap, LastLineNo);
        CalculateRowCounts(TempCSVBuffer, HeaderMap, LastLineNo, ReportRun);
        for LineNo := 2 to LastLineNo do
            if LoadRelevantRow(TempCSVBuffer, HeaderMap, LineNo, ReportRun) then
                LoadedCount += 1;

        ReportRun."Loaded Row Count" := LoadedCount;
        if ReportRun."Relevant Row Count" <> ReportRun."Loaded Row Count" then
            Error('The report cannot be made ready until every relevant row is loaded.');
        ReportRun.Status := ReportRun.Status::Ready;
        ReportRun."Ready At UTC" := CurrentDateTime();
        ReportRun."Last Error" := '';
        ReportRun.Modify(true);

        Merchant.Get(ReportRun."Merchant Account");
        if ReportRun."Report Date" > Merchant."Last Ready Report Date" then
            Merchant."Last Ready Report Date" := ReportRun."Report Date";
        Merchant."Report Overdue" := false;
        Merchant."Report Alert Message" := '';
        Merchant.Modify(true);
    end;

    local procedure ReadReport(var ReportRun: Record "Adyen Report Run"; var TempCSVBuffer: Record "CSV Buffer" temporary; var HeaderMap: Dictionary of [Text, Integer]; var LastLineNo: Integer)
    var
        ReportInStream: InStream;
    begin
        ReportRun.CalcFields(Content);
        if not ReportRun.Content.HasValue() then
            Error('The Adyen report has no content.');
        ReportRun."Report Date" := ResolveReportDate(ReportRun."External Report ID");
        ReportRun.Content.CreateInStream(ReportInStream);
        TempCSVBuffer.LoadDataFromStream(ReportInStream, ',', '"');
        LastLineNo := TempCSVBuffer.GetNumberOfLines();
        if LastLineNo < 1 then
            Error('The Adyen report has no header row.');

        BuildHeaderMap(TempCSVBuffer, HeaderMap);
        ValidateRequiredHeaders(HeaderMap);
    end;

    local procedure CalculateRowCounts(var TempCSVBuffer: Record "CSV Buffer" temporary; HeaderMap: Dictionary of [Text, Integer]; LastLineNo: Integer; var ReportRun: Record "Adyen Report Run")
    var
        LineNo: Integer;
        RelevantCount: Integer;
    begin
        for LineNo := 2 to LastLineNo do
            if IsRelevantRecordType(GetValue(TempCSVBuffer, HeaderMap, LineNo, 'record type')) then
                RelevantCount += 1;

        ReportRun."Total Row Count" := LastLineNo - 1;
        ReportRun."Relevant Row Count" := RelevantCount;
        ReportRun."Loaded Row Count" := 0;
    end;

    procedure ResolveReportDate(ExternalReportId: Text): Date
    var
        Candidate: Text;
        ReportDate: Date;
        FoundDate: Date;
        MatchCount: Integer;
        Position: Integer;
    begin
        if StrLen(ExternalReportId) < 10 then
            Error('Report %1 must contain exactly one yyyy_MM_dd date.', ExternalReportId);
        for Position := 1 to StrLen(ExternalReportId) - 9 do begin
            Candidate := CopyStr(ExternalReportId, Position, 10);
            if IsDatePattern(Candidate) and Evaluate(ReportDate, Candidate.Replace('_', '-'), 9) then begin
                MatchCount += 1;
                FoundDate := ReportDate;
            end;
        end;
        if MatchCount <> 1 then
            Error('Report %1 must contain exactly one yyyy_MM_dd date.', ExternalReportId);
        exit(FoundDate);
    end;

    local procedure LoadRelevantRow(var TempCSVBuffer: Record "CSV Buffer" temporary; HeaderMap: Dictionary of [Text, Integer]; LineNo: Integer; ReportRun: Record "Adyen Report Run"): Boolean
    var
        EventEntry: Record "Adyen Event Entry";
        ExistingEvent: Record "Adyen Event Entry";
        Crypto: Codeunit "Adyen Cryptography";
        RecordType: Text;
        MerchantAccount: Text;
        PaymentPspReference: Text;
        ModificationPspReference: Text;
        OccurredAt: DateTime;
        SourceAmount: Decimal;
        PaymentAmount: Decimal;
        CanonicalRow: Text;
    begin
        RecordType := GetValue(TempCSVBuffer, HeaderMap, LineNo, 'record type');
        if not IsRelevantRecordType(RecordType) then
            exit(false);

        MerchantAccount := GetValue(TempCSVBuffer, HeaderMap, LineNo, 'merchant account');
        if MerchantAccount <> ReportRun."Merchant Account" then
            Error('Report row %1 belongs to merchant %2 instead of %3.', LineNo, MerchantAccount, ReportRun."Merchant Account");
        PaymentPspReference := GetValue(TempCSVBuffer, HeaderMap, LineNo, 'psp reference');
        ModificationPspReference := GetOptionalValue(TempCSVBuffer, HeaderMap, LineNo, 'modification psp reference');
        if PaymentPspReference = '' then
            Error('Report row %1 has no PSP reference.', LineNo);
        if UsesAuthorisedAmount(RecordType) then begin
            if not Evaluate(SourceAmount, GetValue(TempCSVBuffer, HeaderMap, LineNo, 'authorised (pc)'), 9) then
                Error('Report row %1 has an invalid Authorised (PC) value.', LineNo);
        end else
            if not Evaluate(SourceAmount, GetValue(TempCSVBuffer, HeaderMap, LineNo, 'captured (pc)'), 9) then
                Error('Report row %1 has an invalid Captured (PC) value.', LineNo);
        PaymentAmount := Abs(SourceAmount);
        OccurredAt := ParseOccurredAtUtc(
            GetValue(TempCSVBuffer, HeaderMap, LineNo, 'booking date'),
            GetValue(TempCSVBuffer, HeaderMap, LineNo, 'timezone'), LineNo);

        CanonicalRow :=
            MerchantAccount + '|' + PaymentPspReference + '|' + ModificationPspReference + '|' + RecordType + '|' +
            Format(OccurredAt, 0, 9) + '|' + GetValue(TempCSVBuffer, HeaderMap, LineNo, 'payment currency') + '|' +
            Format(SourceAmount, 0, 9) + '|' + GetValue(TempCSVBuffer, HeaderMap, LineNo, 'merchant reference') + '|' +
            GetValue(TempCSVBuffer, HeaderMap, LineNo, 'shopper reference') + '|' +
            GetOptionalValue(TempCSVBuffer, HeaderMap, LineNo, 'payment method') + '|' +
            GetOptionalValue(TempCSVBuffer, HeaderMap, LineNo, 'payment method variant');

        EventEntry.Init();
        EventEntry."Report Row Identity" := Crypto.GenerateSha256(CanonicalRow);
        EventEntry."Transport ID" := Crypto.GenerateSha256(
            ReportRun."File Hash" + '|' + Format(LineNo, 0, 9) + '|' + EventEntry."Report Row Identity");
        EventEntry."Logical Event Key" := Crypto.GenerateSha256(
            LowerCase(MerchantAccount + '|' + RecordType + '|' + PaymentPspReference + '|' + ModificationPspReference));
        EventEntry.Source := EventEntry.Source::Report;
        EventEntry."Report Run Entry No." := ReportRun."Entry No.";
        EventEntry."Report Row No." := LineNo;
        EventEntry."Message Type" := CopyStr(RecordType, 1, MaxStrLen(EventEntry."Message Type"));
        EventEntry."Occurred At UTC" := OccurredAt;
        EventEntry."Received At UTC" := CurrentDateTime();
        EventEntry."Payload Hash" := EventEntry."Report Row Identity";
        EventEntry."Merchant Account" := CopyStr(MerchantAccount, 1, MaxStrLen(EventEntry."Merchant Account"));
        if ModificationPspReference <> '' then
            EventEntry."PSP Reference" := CopyStr(ModificationPspReference, 1, MaxStrLen(EventEntry."PSP Reference"))
        else
            EventEntry."PSP Reference" := CopyStr(PaymentPspReference, 1, MaxStrLen(EventEntry."PSP Reference"));
        EventEntry."Original PSP Reference" := CopyStr(PaymentPspReference, 1, MaxStrLen(EventEntry."Original PSP Reference"));
        EventEntry."Payment PSP Reference" := CopyStr(PaymentPspReference, 1, MaxStrLen(EventEntry."Payment PSP Reference"));
        EventEntry."Merchant Reference" := CopyStr(GetValue(TempCSVBuffer, HeaderMap, LineNo, 'merchant reference'), 1, MaxStrLen(EventEntry."Merchant Reference"));
        EventEntry."Shopper Reference" := CopyStr(GetValue(TempCSVBuffer, HeaderMap, LineNo, 'shopper reference'), 1, MaxStrLen(EventEntry."Shopper Reference"));
        EventEntry."Payment Method" := CopyStr(GetOptionalValue(TempCSVBuffer, HeaderMap, LineNo, 'payment method'), 1, MaxStrLen(EventEntry."Payment Method"));
        if EventEntry."Payment Method" = '' then
            EventEntry."Payment Method" := CopyStr(GetOptionalValue(TempCSVBuffer, HeaderMap, LineNo, 'payment method variant'), 1, MaxStrLen(EventEntry."Payment Method"));
        EventEntry."Success Provided" := true;
        EventEntry.Success := true;
        EventEntry."Currency Code" := CopyStr(UpperCase(GetValue(TempCSVBuffer, HeaderMap, LineNo, 'payment currency')), 1, MaxStrLen(EventEntry."Currency Code"));
        EventEntry.Amount := PaymentAmount;

        if not ExistingEvent.Get(EventEntry."Transport ID") then
            EventEntry.Insert(true)
        else
            if ExistingEvent."Payload Hash" <> EventEntry."Payload Hash" then
                Error('Report transport ID %1 already exists with a different row hash.', EventEntry."Transport ID");
        exit(true);
    end;

    local procedure BuildHeaderMap(var TempCSVBuffer: Record "CSV Buffer" temporary; var HeaderMap: Dictionary of [Text, Integer])
    var
        HeaderName: Text;
    begin
        TempCSVBuffer.SetRange("Line No.", 1);
        if not TempCSVBuffer.FindSet() then
            Error('The Adyen report has no header row.');
        repeat
            HeaderName := LowerCase(DelChr(TempCSVBuffer.Value, '<>', ' '));
            if HeaderName <> '' then begin
                if HeaderMap.ContainsKey(HeaderName) then
                    Error('The report contains duplicate column %1.', TempCSVBuffer.Value);
                HeaderMap.Add(HeaderName, TempCSVBuffer."Field No.");
            end;
        until TempCSVBuffer.Next() = 0;
        TempCSVBuffer.Reset();
    end;

    local procedure ValidateRequiredHeaders(HeaderMap: Dictionary of [Text, Integer])
    begin
        RequireHeader(HeaderMap, 'merchant account');
        RequireHeader(HeaderMap, 'psp reference');
        RequireHeader(HeaderMap, 'merchant reference');
        RequireHeader(HeaderMap, 'payment currency');
        RequireHeader(HeaderMap, 'authorised (pc)');
        RequireHeader(HeaderMap, 'captured (pc)');
        RequireHeader(HeaderMap, 'record type');
        RequireHeader(HeaderMap, 'booking date');
        RequireHeader(HeaderMap, 'timezone');
        RequireHeader(HeaderMap, 'shopper reference');
    end;

    local procedure RequireHeader(HeaderMap: Dictionary of [Text, Integer]; HeaderName: Text)
    begin
        if not HeaderMap.ContainsKey(HeaderName) then
            Error('The Adyen report is missing required column %1.', HeaderName);
    end;

    local procedure GetValue(var TempCSVBuffer: Record "CSV Buffer" temporary; HeaderMap: Dictionary of [Text, Integer]; LineNo: Integer; HeaderName: Text): Text
    var
        FieldNo: Integer;
    begin
        HeaderMap.Get(HeaderName, FieldNo);
        exit(TempCSVBuffer.GetValue(LineNo, FieldNo));
    end;

    local procedure GetOptionalValue(var TempCSVBuffer: Record "CSV Buffer" temporary; HeaderMap: Dictionary of [Text, Integer]; LineNo: Integer; HeaderName: Text): Text
    var
        FieldNo: Integer;
    begin
        if not HeaderMap.Get(HeaderName, FieldNo) then
            exit('');
        exit(TempCSVBuffer.GetValue(LineNo, FieldNo));
    end;

    local procedure IsRelevantRecordType(RecordType: Text): Boolean
    var
        Normalized: Text;
    begin
        Normalized := NormalizeRecordType(RecordType);
        exit(Normalized in [
            'AUTHORISED', 'SENTFORSETTLE', 'SETTLED', 'CAPTUREFAILED', 'CANCELLED', 'EXPIRED', 'REFUNDED', 'REFUNDFAILED',
            'REFUNDEDREVERSED', 'CHARGEBACK', 'CHARGEBACKREVERSED', 'SECONDCHARGEBACK', 'SETTLEDREVERSED']);
    end;

    local procedure UsesAuthorisedAmount(RecordType: Text): Boolean
    begin
        exit(NormalizeRecordType(RecordType) in ['AUTHORISED', 'CANCELLED', 'EXPIRED']);
    end;

    local procedure NormalizeRecordType(RecordType: Text): Text
    begin
        exit(UpperCase(DelChr(RecordType, '=', '_- ')));
    end;

    local procedure ParseOccurredAtUtc(BookingDateText: Text; TimeZoneText: Text; LineNo: Integer): DateTime
    var
        LocalBookingDateTime: DateTime;
        OccurredAtUtc: DateTime;
    begin
        if not TryParseBookingDateTime(BookingDateText, LocalBookingDateTime) then
            Error('Report row %1 has an invalid booking date.', LineNo);

        TimeZoneText := UpperCase(TimeZoneText.Trim());
        if TimeZoneText = '' then
            Error('Report row %1 has no TimeZone.', LineNo);
        if not TryConvertToUtc(LocalBookingDateTime, TimeZoneText, OccurredAtUtc) then
            Error('Report row %1 has unsupported TimeZone %2.', LineNo, TimeZoneText);
        exit(OccurredAtUtc);
    end;

    local procedure TryParseBookingDateTime(BookingDateText: Text; var BookingDateTime: DateTime): Boolean
    var
        BookingDate: Date;
        BookingTime: Time;
    begin
        BookingDateText := BookingDateText.Trim();
        if not IsIsoBookingDateTimePattern(BookingDateText) then
            exit(false);
        if not Evaluate(BookingDate, CopyStr(BookingDateText, 1, 10), 9) then
            exit(false);
        if not Evaluate(BookingTime, CopyStr(BookingDateText, 12, 8), 9) then
            exit(false);
        BookingDateTime := CreateDateTime(BookingDate, BookingTime);
        exit(true);
    end;

    local procedure TryConvertToUtc(LocalBookingDateTime: DateTime; TimeZoneText: Text; var OccurredAtUtc: DateTime): Boolean
    var
        Offset: Duration;
    begin
        case TimeZoneText of
            'CET':
                Offset := 3600000;
            'CEST':
                Offset := 7200000;
            else
                exit(false);
        end;
        OccurredAtUtc := LocalBookingDateTime - Offset;
        exit(true);
    end;

    local procedure IsIsoBookingDateTimePattern(Value: Text): Boolean
    begin
        if StrLen(Value) <> 19 then
            exit(false);
        exit(
            IsDigit(CopyStr(Value, 1, 1)) and IsDigit(CopyStr(Value, 2, 1)) and
            IsDigit(CopyStr(Value, 3, 1)) and IsDigit(CopyStr(Value, 4, 1)) and
            (CopyStr(Value, 5, 1) = '-') and
            IsDigit(CopyStr(Value, 6, 1)) and IsDigit(CopyStr(Value, 7, 1)) and
            (CopyStr(Value, 8, 1) = '-') and
            IsDigit(CopyStr(Value, 9, 1)) and IsDigit(CopyStr(Value, 10, 1)) and
            (CopyStr(Value, 11, 1) = ' ') and
            IsDigit(CopyStr(Value, 12, 1)) and IsDigit(CopyStr(Value, 13, 1)) and
            (CopyStr(Value, 14, 1) = ':') and
            IsDigit(CopyStr(Value, 15, 1)) and IsDigit(CopyStr(Value, 16, 1)) and
            (CopyStr(Value, 17, 1) = ':') and
            IsDigit(CopyStr(Value, 18, 1)) and IsDigit(CopyStr(Value, 19, 1)));
    end;

    local procedure IsDatePattern(Value: Text): Boolean
    begin
        if StrLen(Value) <> 10 then
            exit(false);
        exit(
            IsDigit(CopyStr(Value, 1, 1)) and IsDigit(CopyStr(Value, 2, 1)) and
            IsDigit(CopyStr(Value, 3, 1)) and IsDigit(CopyStr(Value, 4, 1)) and
            (CopyStr(Value, 5, 1) = '_') and
            IsDigit(CopyStr(Value, 6, 1)) and IsDigit(CopyStr(Value, 7, 1)) and
            (CopyStr(Value, 8, 1) = '_') and
            IsDigit(CopyStr(Value, 9, 1)) and IsDigit(CopyStr(Value, 10, 1)));
    end;

    local procedure IsDigit(Value: Text): Boolean
    begin
        exit((Value >= '0') and (Value <= '9'));
    end;
}
