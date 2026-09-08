table 72002 "Adyen Webhook Request"
{
    Caption = 'Adyen Webhook Request';
    DataClassification = CustomerContent;
    LookupPageId = "Adyen Webhook Requests";
    DrillDownPageId = "Adyen Webhook Requests";

    fields
    {
        field(1; "Entry No."; BigInteger)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            DataClassification = SystemMetadata;
        }
        field(2; "Received At UTC"; DateTime) { Caption = 'Received At UTC'; }
        field(3; "Content Type"; Text[100]) { Caption = 'Content Type'; }
        field(4; "Flow Run ID"; Text[250])
        {
            Caption = 'Flow Run ID';
            DataClassification = SystemMetadata;
        }
        field(5; Payload; Blob)
        {
            Caption = 'Payload';
            SubType = Json;
        }
        field(6; "Payload Hash"; Code[64])
        {
            Caption = 'Payload Hash';
            DataClassification = SystemMetadata;
        }
        field(7; Status; Enum "Adyen Process Status") { Caption = 'Status'; }
        field(8; "Item Count"; Integer) { Caption = 'Item Count'; Editable = false; }
        field(9; "Normalized Item Count"; Integer) { Caption = 'Normalized Item Count'; Editable = false; }
        field(10; "Retry Count"; Integer) { Caption = 'Retry Count'; Editable = false; }
        field(11; "Last Error"; Text[2048]) { Caption = 'Last Error'; Editable = false; }
        field(12; "Processed At UTC"; DateTime) { Caption = 'Processed At UTC'; Editable = false; }
        field(13; "Raw Content Purged"; Boolean) { Caption = 'Raw Content Purged'; Editable = false; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(HashKey; "Payload Hash") { Unique = true; }
        key(FlowRunKey; "Flow Run ID") { }
        key(StatusKey; Status, "Received At UTC") { }
    }

    trigger OnInsert()
    begin
        TestField("Payload Hash");
        if "Received At UTC" = 0DT then
            "Received At UTC" := CurrentDateTime();
        Status := Status::Received;
    end;
}
