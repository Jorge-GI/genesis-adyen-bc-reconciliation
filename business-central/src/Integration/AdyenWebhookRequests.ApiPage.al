page 72020 "Adyen Webhook Requests API"
{
    PageType = API;
    APIPublisher = 'genesisimport';
    APIGroup = 'adyen';
    APIVersion = 'v1.0';
    EntityName = 'adyenWebhookRequest';
    EntitySetName = 'adyenWebhookRequests';
    EntityCaption = 'Adyen Webhook Request';
    EntitySetCaption = 'Adyen Webhook Requests';
    SourceTable = "Adyen Webhook Request";
    SourceTableTemporary = true;
    ODataKeyFields = SystemId;
    DelayedInsert = true;
    InsertAllowed = true;
    ModifyAllowed = false;
    DeleteAllowed = false;
    Extensible = false;
    Permissions = tabledata "Adyen Webhook Request" = RI;

    layout
    {
        area(Content)
        {
            repeater(Requests)
            {
                field(id; Rec.SystemId) { Caption = 'Id'; Editable = false; }
                field(receivedAtUtc; Rec."Received At UTC") { Caption = 'Received At UTC'; }
                field(contentType; Rec."Content Type") { Caption = 'Content Type'; }
                field(flowRunId; Rec."Flow Run ID") { Caption = 'Flow Run ID'; }
                field(payload; Rec.Payload) { Caption = 'Payload'; }
                field(payloadHash; Rec."Payload Hash") { Caption = 'Payload Hash'; Editable = false; }
                field(status; Rec.Status) { Caption = 'Status'; Editable = false; }
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        StoredRequest: Record "Adyen Webhook Request";
        Intake: Codeunit "Adyen Webhook Intake";
        PayloadInStream: InStream;
        PayloadOutStream: OutStream;
    begin
        StoredRequest.Init();
        StoredRequest."Received At UTC" := Rec."Received At UTC";
        StoredRequest."Content Type" := Rec."Content Type";
        StoredRequest."Flow Run ID" := Rec."Flow Run ID";
        Rec.CalcFields(Payload);
        Rec.Payload.CreateInStream(PayloadInStream);
        StoredRequest.Payload.CreateOutStream(PayloadOutStream);
        CopyStream(PayloadOutStream, PayloadInStream);
        Intake.Accept(StoredRequest);

        Rec."Entry No." := StoredRequest."Entry No.";
        Rec.SystemId := StoredRequest.SystemId;
        Rec."Received At UTC" := StoredRequest."Received At UTC";
        Rec."Payload Hash" := StoredRequest."Payload Hash";
        Rec.Status := StoredRequest.Status;
        exit(false);
    end;
}
