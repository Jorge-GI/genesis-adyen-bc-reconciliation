page 72020 "Adyen Inbound Messages API"
{
    PageType = API;
    APIPublisher = 'genesisimport';
    APIGroup = 'adyen';
    APIVersion = 'v1.0';
    EntityName = 'adyenInboundMessage';
    EntitySetName = 'adyenInboundMessages';
    EntityCaption = 'Adyen Inbound Message';
    EntitySetCaption = 'Adyen Inbound Messages';
    SourceTable = "Adyen Inbox Entry";
    ODataKeyFields = "Transport ID";
    DelayedInsert = true;
    InsertAllowed = true;
    ModifyAllowed = false;
    DeleteAllowed = false;
    Extensible = false;

    layout
    {
        area(Content)
        {
            repeater(Messages)
            {
                field(transportId; Rec."Transport ID") { Caption = 'Transport ID'; }
                field(logicalEventKey; Rec."Logical Event Key") { Caption = 'Logical Event Key'; }
                field(source; Rec.Source) { Caption = 'Source'; }
                field(messageType; Rec."Message Type") { Caption = 'Message Type'; }
                field(occurredAtUtc; Rec."Occurred At UTC") { Caption = 'Occurred At UTC'; }
                field(receivedAtUtc; Rec."Received At UTC") { Caption = 'Received At UTC'; }
                field(payloadHash; Rec."Payload Hash") { Caption = 'Payload Hash'; }
                field(merchantAccount; Rec."Merchant Account") { Caption = 'Merchant Account'; }
                field(environment; Rec.Environment) { Caption = 'Environment'; }
                field(pspReference; Rec."PSP Reference") { Caption = 'PSP Reference'; }
                field(originalPspReference; Rec."Original PSP Reference") { Caption = 'Original PSP Reference'; }
                field(merchantReference; Rec."Merchant Reference") { Caption = 'Merchant Reference'; }
                field(shopperReference; Rec."Shopper Reference") { Caption = 'Shopper Reference'; }
                field(paymentMethod; Rec."Payment Method") { Caption = 'Payment Method'; }
                field(successProvided; Rec."Success Provided") { Caption = 'Success Provided'; }
                field(success; Rec.Success) { Caption = 'Success'; }
                field(currencyCode; Rec."Currency Code") { Caption = 'Currency Code'; }
                field(amount; Rec.Amount) { Caption = 'Amount'; }
                field(reportRunId; Rec."Report Run ID") { Caption = 'Report Run ID'; }
                field(reportRowIdentity; Rec."Report Row Identity") { Caption = 'Report Row Identity'; }
                field(rawArchiveReference; Rec."Raw Archive Reference") { Caption = 'Raw Archive Reference'; }
                field(status; Rec.Status) { Caption = 'Status'; Editable = false; }
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        ExistingEntry: Record "Adyen Inbox Entry";
        Setup: Record "Adyen Setup";
    begin
        Setup.GetRecordOnce();
        Setup.TestField(Enabled, true);
        if Rec."Merchant Account" <> Setup."Merchant Account" then
            Error('Merchant account %1 is not configured for this company.', Rec."Merchant Account");
        if Rec.Environment <> Setup.Environment then
            Error('The inbound environment does not match Adyen Setup.');

        if ExistingEntry.Get(Rec."Transport ID") then begin
            if ExistingEntry."Payload Hash" <> Rec."Payload Hash" then
                Error('Transport ID %1 already exists with a different payload hash.', Rec."Transport ID");
            Rec := ExistingEntry;
            exit(false);
        end;

        Rec.Insert(true);
        exit(false);
    end;
}
