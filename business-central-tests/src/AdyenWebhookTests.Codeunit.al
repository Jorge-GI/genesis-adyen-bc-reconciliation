codeunit 72151 "Adyen Webhook Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure MultiItemWebhookIsValidatedStoredAndNormalized()
    var
        EventEntry: Record "Adyen Event Entry";
        WebhookRequest: Record "Adyen Webhook Request";
        Intake: Codeunit "Adyen Webhook Intake";
    begin
        ConfigureIntegration();
        BuildRequest(WebhookRequest, 'flow-multi', BuildEnvelope(2));
        AssertTrue(Intake.Accept(WebhookRequest), 'The first delivery must be accepted.');
        Intake.Normalize(WebhookRequest);

        EventEntry.SetRange("Webhook Request Entry No.", WebhookRequest."Entry No.");
        AssertEqualInteger(2, EventEntry.Count(), 'Both notification items must be normalized.');
        AssertEqualInteger(2, WebhookRequest."Normalized Item Count", 'The request must retain its normalized item count.');
        AssertTrue(WebhookRequest.Status = WebhookRequest.Status::Processed, 'The request must be marked processed.');
    end;

    [Test]
    procedure PlainTextApiPayloadIsStoredInBlob()
    var
        WebhookRequest: Record "Adyen Webhook Request";
        Intake: Codeunit "Adyen Webhook Intake";
        PayloadInStream: InStream;
        ActualPayload: Text;
        ExpectedPayload: Text;
    begin
        ConfigureIntegration();
        ExpectedPayload := BuildEnvelope(1);
        WebhookRequest.Init();
        WebhookRequest."Flow Run ID" := 'flow-text';
        WebhookRequest."Content Type" := 'application/json';

        AssertTrue(
            Intake.AcceptText(WebhookRequest, ExpectedPayload),
            'The connector-compatible JSON text payload must be accepted.');

        WebhookRequest.CalcFields(Payload);
        WebhookRequest.Payload.CreateInStream(PayloadInStream, TextEncoding::UTF8);
        PayloadInStream.ReadText(ActualPayload);
        AssertEqualText(ExpectedPayload, ActualPayload, 'BC must retain the JSON text in the raw-request BLOB.');
    end;

    [Test]
    procedure EmptyTextApiPayloadIsRejected()
    var
        WebhookRequest: Record "Adyen Webhook Request";
        Intake: Codeunit "Adyen Webhook Intake";
    begin
        ConfigureIntegration();
        WebhookRequest.Init();
        WebhookRequest."Flow Run ID" := 'flow-empty-text';
        WebhookRequest."Content Type" := 'application/json';

        asserterror Intake.AcceptText(WebhookRequest, '');
    end;

    [Test]
    procedure ExactDuplicateDeliveryIsIdempotent()
    var
        FirstRequest: Record "Adyen Webhook Request";
        DuplicateRequest: Record "Adyen Webhook Request";
        Intake: Codeunit "Adyen Webhook Intake";
        FirstEntryNo: BigInteger;
    begin
        ConfigureIntegration();
        BuildRequest(FirstRequest, 'flow-duplicate', BuildEnvelope(1));
        AssertTrue(Intake.Accept(FirstRequest), 'The first delivery must be accepted.');
        FirstEntryNo := FirstRequest."Entry No.";

        BuildRequest(DuplicateRequest, 'flow-duplicate', BuildEnvelope(1));
        AssertFalse(Intake.Accept(DuplicateRequest), 'An exact retry must not create another request.');
        AssertTrue(DuplicateRequest."Entry No." = FirstEntryNo, 'The exact retry must resolve to the retained request.');
    end;

    [Test]
    procedure FlowRunHashConflictIsRejected()
    var
        FirstRequest: Record "Adyen Webhook Request";
        ConflictingRequest: Record "Adyen Webhook Request";
        Intake: Codeunit "Adyen Webhook Intake";
    begin
        ConfigureIntegration();
        BuildRequest(FirstRequest, 'flow-conflict', BuildEnvelope(1));
        Intake.Accept(FirstRequest);

        BuildRequest(ConflictingRequest, 'flow-conflict', BuildEnvelope(1) + ' ');
        asserterror Intake.Accept(ConflictingRequest);
    end;

    [Test]
    procedure ChangedTransportRetainsTheSameLogicalEvent()
    var
        EventEntry: Record "Adyen Event Entry";
        FirstEvent: Record "Adyen Event Entry";
        FirstRequest: Record "Adyen Webhook Request";
        RetransmittedRequest: Record "Adyen Webhook Request";
        Intake: Codeunit "Adyen Webhook Intake";
    begin
        ConfigureIntegration();
        BuildRequest(FirstRequest, 'flow-transport-1', BuildEnvelope(1));
        Intake.Accept(FirstRequest);
        Intake.Normalize(FirstRequest);
        EventEntry.SetRange("Webhook Request Entry No.", FirstRequest."Entry No.");
        EventEntry.FindFirst();
        FirstEvent := EventEntry;

        BuildRequest(RetransmittedRequest, 'flow-transport-2', BuildEnvelope(1) + ' ');
        AssertTrue(Intake.Accept(RetransmittedRequest), 'A changed transport envelope must be retained for audit.');
        Intake.Normalize(RetransmittedRequest);
        EventEntry.SetRange("Webhook Request Entry No.", RetransmittedRequest."Entry No.");
        EventEntry.FindFirst();

        AssertTrue(EventEntry."Transport ID" <> FirstEvent."Transport ID", 'Transport identities must differ.');
        AssertTrue(EventEntry."Logical Event Key" = FirstEvent."Logical Event Key", 'The retransmitted business event must retain one logical identity.');
    end;

    [Test]
    procedure EnvironmentAndMerchantAreRejectedBeforePersistence()
    var
        Merchant: Record "Adyen Merchant";
        Setup: Record "Adyen Setup";
        Request: Record "Adyen Webhook Request";
        Intake: Codeunit "Adyen Webhook Intake";
    begin
        ConfigureIntegration();
        Setup.Get('SETUP');
        Setup.Environment := Setup.Environment::Live;
        Setup.Modify(true);
        BuildRequest(Request, 'flow-environment', BuildEnvelope(1));
        asserterror Intake.Accept(Request);

        Setup.Environment := Setup.Environment::Test;
        Setup.Modify(true);
        Merchant.Get('GenesisMerchant');
        Merchant.Delete(true);
        BuildRequest(Request, 'flow-merchant', BuildEnvelope(1));
        asserterror Intake.Accept(Request);
    end;

    [Test]
    procedure PayloadLimitIsEnforced()
    var
        Setup: Record "Adyen Setup";
        Request: Record "Adyen Webhook Request";
        Intake: Codeunit "Adyen Webhook Intake";
        Payload: Text;
    begin
        ConfigureIntegration();
        Setup.Get('SETUP');
        Setup."Max Webhook Payload Bytes" := 1024;
        Setup.Modify(true);
        Payload := BuildEnvelope(1) + PadStr('', 1500, ' ');
        BuildRequest(Request, 'flow-large', Payload);

        asserterror Intake.Accept(Request);
    end;

    [Test]
    procedure NonJsonContentTypeIsRejected()
    var
        Request: Record "Adyen Webhook Request";
        Intake: Codeunit "Adyen Webhook Intake";
    begin
        ConfigureIntegration();
        BuildRequest(Request, 'flow-content-type', BuildEnvelope(1));
        Request."Content Type" := 'text/plain';

        asserterror Intake.Accept(Request);
    end;

    local procedure ConfigureIntegration()
    var
        Merchant: Record "Adyen Merchant";
        Setup: Record "Adyen Setup";
        Credentials: Codeunit "Adyen Credentials";
    begin
        Setup.GetRecordOnce();
        Setup.Enabled := true;
        Setup.Environment := Setup.Environment::Test;
        Setup."Max Webhook Payload Bytes" := 1048576;
        Setup.Modify(true);
        Credentials.SetCurrentHmacHex(HmacKey());

        if Merchant.Get('GenesisMerchant') then
            Merchant.Delete(true);
        Merchant.Init();
        Merchant."Merchant Account" := 'GenesisMerchant';
        Merchant.Enabled := true;
        Merchant.Insert(true);
    end;

    local procedure BuildRequest(var Request: Record "Adyen Webhook Request"; FlowRunId: Text; Payload: Text)
    var
        PayloadOutStream: OutStream;
    begin
        Clear(Request);
        Request.Init();
        Request."Flow Run ID" := FlowRunId;
        Request."Content Type" := 'application/json';
        Request.Payload.CreateOutStream(PayloadOutStream, TextEncoding::UTF8);
        PayloadOutStream.WriteText(Payload);
    end;

    local procedure BuildEnvelope(ItemCount: Integer): Text
    var
        Item: Text;
        Items: Text;
        Index: Integer;
    begin
        Item := '{"NotificationRequestItem":{"additionalData":{"hmacSignature":"LkSKgyRPvceAQl8+bWrDIVTejATF56CjvObTPC9CNDw="},"amount":{"currency":"EUR","value":12345},"eventCode":"AUTHORISATION","eventDate":"2026-09-03T10:00:00Z","merchantAccountCode":"GenesisMerchant","merchantReference":"ORDER:1\\A","pspReference":"8831234567890123","success":"true"}}';
        for Index := 1 to ItemCount do begin
            if Items <> '' then
                Items += ',';
            Items += Item;
        end;
        exit('{"live":"false","notificationItems":[' + Items + ']}');
    end;

    local procedure HmacKey(): Text
    begin
        exit('00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff');
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

    local procedure AssertEqualText(Expected: Text; Actual: Text; FailureMessage: Text)
    begin
        if Expected <> Actual then
            Error('%1 Expected %2, actual %3.', FailureMessage, Expected, Actual);
    end;
}
