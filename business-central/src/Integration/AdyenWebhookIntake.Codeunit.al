codeunit 72034 "Adyen Webhook Intake"
{
    Permissions =
        tabledata "Adyen Setup" = R,
        tabledata "Adyen Merchant" = R,
        tabledata "Adyen Webhook Request" = RI;

    procedure AcceptText(var WebhookRequest: Record "Adyen Webhook Request"; PayloadText: Text): Boolean
    var
        PayloadOutStream: OutStream;
    begin
        if PayloadText = '' then
            Error('The webhook payload is required.');

        WebhookRequest.Payload.CreateOutStream(PayloadOutStream, TextEncoding::UTF8);
        PayloadOutStream.WriteText(PayloadText);
        Clear(PayloadOutStream);
        exit(Accept(WebhookRequest));
    end;

    procedure Accept(var WebhookRequest: Record "Adyen Webhook Request"): Boolean
    var
        ExistingRequest: Record "Adyen Webhook Request";
        Setup: Record "Adyen Setup";
        PayloadJson: JsonObject;
        PayloadText: Text;
        ItemCount: Integer;
    begin
        Setup.GetRecordOnce();
        Setup.ValidateForIntake();
        if CopyStr(LowerCase(WebhookRequest."Content Type"), 1, 16) <> 'application/json' then
            Error('The webhook content type must be application/json.');
        PayloadText := ReadPayload(WebhookRequest, Setup."Max Webhook Payload Bytes");
        if not PayloadJson.ReadFrom(PayloadText) then
            Error('The webhook payload is not valid JSON.');

        ItemCount := ValidateEnvelope(PayloadJson, Setup);
        WebhookRequest."Payload Hash" := GeneratePayloadBlobHash(WebhookRequest);

        if WebhookRequest."Flow Run ID" <> '' then begin
            ExistingRequest.SetCurrentKey("Flow Run ID");
            ExistingRequest.SetRange("Flow Run ID", WebhookRequest."Flow Run ID");
            if ExistingRequest.FindFirst() then begin
                if ExistingRequest."Payload Hash" <> WebhookRequest."Payload Hash" then
                    Error('Flow run %1 was already accepted with a different payload hash.', WebhookRequest."Flow Run ID");
                WebhookRequest := ExistingRequest;
                exit(false);
            end;
            ExistingRequest.Reset();
        end;

        ExistingRequest.SetCurrentKey("Payload Hash");
        ExistingRequest.SetRange("Payload Hash", WebhookRequest."Payload Hash");
        if ExistingRequest.FindFirst() then begin
            WebhookRequest := ExistingRequest;
            exit(false);
        end;

        WebhookRequest."Item Count" := ItemCount;
        WebhookRequest.Status := WebhookRequest.Status::Received;
        WebhookRequest.Insert(true);
        exit(true);
    end;

    procedure Normalize(var WebhookRequest: Record "Adyen Webhook Request")
    var
        EventEntry: Record "Adyen Event Entry";
        PayloadJson: JsonObject;
        NotificationItems: JsonArray;
        Item: JsonObject;
        PayloadText: Text;
        ItemIndex: Integer;
    begin
        PayloadText := ReadPayload(WebhookRequest, 0);
        PayloadJson.ReadFrom(PayloadText);
        NotificationItems := GetArray(PayloadJson, 'notificationItems');

        for ItemIndex := 0 to NotificationItems.Count() - 1 do begin
            Item := GetNotificationItem(NotificationItems, ItemIndex);
            BuildEvent(EventEntry, WebhookRequest, Item, ItemIndex);
            InsertEventIdempotently(EventEntry);
        end;

        WebhookRequest."Normalized Item Count" := NotificationItems.Count();
        WebhookRequest.Status := WebhookRequest.Status::Processed;
        WebhookRequest."Processed At UTC" := CurrentDateTime();
        WebhookRequest."Last Error" := '';
        WebhookRequest.Modify(true);
    end;

    local procedure GeneratePayloadBlobHash(var WebhookRequest: Record "Adyen Webhook Request"): Code[64]
    var
        Crypto: Codeunit "Adyen Cryptography";
        PayloadInStream: InStream;
    begin
        LoadPersistedPayload(WebhookRequest);
        WebhookRequest.Payload.CreateInStream(PayloadInStream);
        exit(Crypto.GenerateStreamHash(PayloadInStream));
    end;

    local procedure ValidateEnvelope(PayloadJson: JsonObject; Setup: Record "Adyen Setup"): Integer
    var
        Crypto: Codeunit "Adyen Cryptography";
        Merchant: Record "Adyen Merchant";
        NotificationItems: JsonArray;
        Item: JsonObject;
        LiveValue: Text;
        ExpectedLive: Boolean;
        ActualLive: Boolean;
        ItemIndex: Integer;
        MerchantAccount: Text;
    begin
        LiveValue := LowerCase(GetText(PayloadJson, 'live'));
        case LiveValue of
            'true':
                ActualLive := true;
            'false':
                ActualLive := false;
            else
                Error('The webhook live property must be true or false.');
        end;
        ExpectedLive := Setup.Environment = Setup.Environment::Live;
        if ActualLive <> ExpectedLive then
            Error('The webhook environment does not match Adyen Setup.');

        NotificationItems := GetArray(PayloadJson, 'notificationItems');
        if NotificationItems.Count() = 0 then
            Error('The webhook contains no notification items.');

        for ItemIndex := 0 to NotificationItems.Count() - 1 do begin
            Item := GetNotificationItem(NotificationItems, ItemIndex);
            MerchantAccount := GetText(Item, 'merchantAccountCode');
            if not Merchant.Get(MerchantAccount) or not Merchant.Enabled or
               (Merchant."Merchant Account" <> MerchantAccount)
            then
                Error('Merchant account %1 is not enabled for this company.', MerchantAccount);
            if not Crypto.VerifyNotification(Item) then
                Error('The webhook HMAC signature is invalid.');
        end;
        exit(NotificationItems.Count());
    end;

    local procedure BuildEvent(var EventEntry: Record "Adyen Event Entry"; WebhookRequest: Record "Adyen Webhook Request"; Item: JsonObject; ItemIndex: Integer)
    var
        Crypto: Codeunit "Adyen Cryptography";
        Money: Codeunit "Adyen Money";
        AmountObject: JsonObject;
        MinorUnits: BigInteger;
        EventDateTime: DateTime;
        SuccessText: Text;
        CurrencyCode: Code[10];
    begin
        Clear(EventEntry);
        EventEntry.Init();
        EventEntry."Transport ID" := Crypto.GenerateSha256(WebhookRequest."Payload Hash" + '|' + Format(ItemIndex, 0, 9));
        EventEntry.Source := EventEntry.Source::Webhook;
        EventEntry."Webhook Request Entry No." := WebhookRequest."Entry No.";
        EventEntry."Message Type" := CopyStr(GetText(Item, 'eventCode'), 1, MaxStrLen(EventEntry."Message Type"));
        Evaluate(EventDateTime, GetText(Item, 'eventDate'), 9);
        EventEntry."Occurred At UTC" := EventDateTime;
        EventEntry."Received At UTC" := WebhookRequest."Received At UTC";
        EventEntry."Payload Hash" := WebhookRequest."Payload Hash";
        EventEntry."Merchant Account" := CopyStr(GetText(Item, 'merchantAccountCode'), 1, MaxStrLen(EventEntry."Merchant Account"));
        EventEntry."PSP Reference" := CopyStr(GetText(Item, 'pspReference'), 1, MaxStrLen(EventEntry."PSP Reference"));
        if UpperCase(DelChr(EventEntry."Message Type", '=', '_- ')) = 'REPORTAVAILABLE' then
            EventEntry."External Report ID" := CopyStr(GetText(Item, 'pspReference'), 1, MaxStrLen(EventEntry."External Report ID"));
        EventEntry."Original PSP Reference" := CopyStr(GetOptionalText(Item, 'originalReference'), 1, MaxStrLen(EventEntry."Original PSP Reference"));
        if EventEntry."Original PSP Reference" <> '' then
            EventEntry."Payment PSP Reference" := CopyStr(EventEntry."Original PSP Reference", 1, MaxStrLen(EventEntry."Payment PSP Reference"))
        else
            EventEntry."Payment PSP Reference" := CopyStr(EventEntry."PSP Reference", 1, MaxStrLen(EventEntry."Payment PSP Reference"));
        EventEntry."Merchant Reference" := CopyStr(GetOptionalText(Item, 'merchantReference'), 1, MaxStrLen(EventEntry."Merchant Reference"));
        EventEntry."Shopper Reference" := CopyStr(GetAdditionalDataValue(Item, 'shopperReference'), 1, MaxStrLen(EventEntry."Shopper Reference"));
        EventEntry."Payment Method" := CopyStr(GetOptionalText(Item, 'paymentMethod'), 1, MaxStrLen(EventEntry."Payment Method"));
        EventEntry.Reason := CopyStr(GetOptionalText(Item, 'reason'), 1, MaxStrLen(EventEntry.Reason));
        SuccessText := LowerCase(GetOptionalText(Item, 'success'));
        EventEntry."Success Provided" := SuccessText in ['true', 'false'];
        EventEntry.Success := SuccessText = 'true';

        if TryGetObject(Item, 'amount', AmountObject) then begin
            CurrencyCode := CopyStr(UpperCase(GetOptionalText(AmountObject, 'currency')), 1, MaxStrLen(CurrencyCode));
            EventEntry."Currency Code" := CurrencyCode;
            if Evaluate(MinorUnits, GetOptionalText(AmountObject, 'value'), 9) then
                EventEntry.Amount := Abs(Money.ToMajorUnits(MinorUnits, CurrencyCode));
        end;

        EventEntry."Logical Event Key" := Crypto.GenerateSha256(
            LowerCase(
                EventEntry."Merchant Account" + '|' + EventEntry."Message Type" + '|' +
                EventEntry."PSP Reference" + '|' + EventEntry."External Report ID" + '|' +
                EventEntry."Original PSP Reference" + '|' + SuccessText + '|' +
                Format(EventEntry."Occurred At UTC", 0, 9) + '|' + EventEntry."Currency Code" + '|' +
                Format(EventEntry.Amount, 0, 9)));
    end;

    local procedure InsertEventIdempotently(var EventEntry: Record "Adyen Event Entry")
    var
        ExistingEvent: Record "Adyen Event Entry";
    begin
        if not ExistingEvent.Get(EventEntry."Transport ID") then
            EventEntry.Insert(true)
        else
            if ExistingEvent."Payload Hash" <> EventEntry."Payload Hash" then
                Error('Transport ID %1 already exists with a different payload hash.', EventEntry."Transport ID");
    end;

    local procedure ReadPayload(var WebhookRequest: Record "Adyen Webhook Request"; MaximumBytes: Integer): Text
    var
        PayloadInStream: InStream;
        PayloadText: Text;
        PayloadLine: Text;
    begin
        LoadPersistedPayload(WebhookRequest);
        if not WebhookRequest.Payload.HasValue() then
            Error('The webhook payload is required.');
        if (MaximumBytes > 0) and (WebhookRequest.Payload.Length() > MaximumBytes) then
            Error('The webhook payload exceeds the configured maximum of %1 bytes.', MaximumBytes);
        WebhookRequest.Payload.CreateInStream(PayloadInStream, TextEncoding::UTF8);
        while not PayloadInStream.EOS() do begin
            PayloadInStream.ReadText(PayloadLine);
            PayloadText += PayloadLine;
        end;
        if PayloadText = '' then
            Error('The webhook payload is empty.');
        exit(PayloadText);
    end;

    local procedure LoadPersistedPayload(var WebhookRequest: Record "Adyen Webhook Request")
    begin
        if WebhookRequest."Entry No." <> 0 then
            WebhookRequest.CalcFields(Payload);
    end;

    local procedure GetNotificationItem(NotificationItems: JsonArray; ItemIndex: Integer): JsonObject
    var
        ContainerToken: JsonToken;
        ItemToken: JsonToken;
        Container: JsonObject;
    begin
        NotificationItems.Get(ItemIndex, ContainerToken);
        if not ContainerToken.IsObject() then
            Error('Webhook notification item %1 is not an object.', ItemIndex + 1);
        Container := ContainerToken.AsObject();
        if not Container.Get('NotificationRequestItem', ItemToken) or not ItemToken.IsObject() then
            Error('Webhook notification item %1 has no NotificationRequestItem object.', ItemIndex + 1);
        exit(ItemToken.AsObject());
    end;

    local procedure GetArray(Object: JsonObject; Name: Text): JsonArray
    var
        Token: JsonToken;
    begin
        if not Object.Get(Name, Token) or not Token.IsArray() then
            Error('The webhook property %1 must be an array.', Name);
        exit(Token.AsArray());
    end;

    local procedure TryGetObject(Object: JsonObject; Name: Text; var Result: JsonObject): Boolean
    var
        Token: JsonToken;
    begin
        if not Object.Get(Name, Token) or not Token.IsObject() then
            exit(false);
        Result := Token.AsObject();
        exit(true);
    end;

    local procedure GetText(Object: JsonObject; Name: Text): Text
    var
        Value: Text;
    begin
        Value := GetOptionalText(Object, Name);
        if Value = '' then
            Error('The webhook property %1 is required.', Name);
        exit(Value);
    end;

    local procedure GetOptionalText(Object: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if not Object.Get(Name, Token) or not Token.IsValue() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    local procedure GetAdditionalDataValue(Item: JsonObject; Name: Text): Text
    var
        AdditionalData: JsonObject;
    begin
        if not TryGetObject(Item, 'additionalData', AdditionalData) then
            exit('');
        exit(GetOptionalText(AdditionalData, Name));
    end;
}
