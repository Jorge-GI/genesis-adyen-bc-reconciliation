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
            ToolTip = 'Specifies the internal entry number assigned to the retained webhook request.';
        }
        field(2; "Received At UTC"; DateTime)
        {
            Caption = 'Received At UTC';
            ToolTip = 'Specifies the date and time in UTC when Business Central accepted the webhook request.';
        }
        field(3; "Content Type"; Text[100])
        {
            Caption = 'Content Type';
            ToolTip = 'Specifies the media type supplied with the webhook request.';
        }
        field(4; "Flow Run ID"; Text[250])
        {
            Caption = 'Flow Run ID';
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the Power Automate flow-run identifier used to correlate and safely retry the webhook delivery.';
        }
        field(5; Payload; Blob)
        {
            Caption = 'Payload';
            SubType = Json;
            ToolTip = 'Specifies the complete retained Adyen webhook envelope as JSON.';
        }
        field(6; "Payload Hash"; Code[64])
        {
            Caption = 'Payload Hash';
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the SHA-256 identity used to detect duplicate webhook payloads.';
        }
        field(7; Status; Enum "Adyen Process Status")
        {
            Caption = 'Status';
            ToolTip = 'Specifies whether the webhook request is waiting, processing, processed, ignored, or in error.';
        }
        field(8; "Item Count"; Integer)
        {
            Caption = 'Item Count';
            Editable = false;
            ToolTip = 'Specifies the number of notification items in the accepted webhook envelope.';
        }
        field(9; "Normalized Item Count"; Integer)
        {
            Caption = 'Normalized Item Count';
            Editable = false;
            ToolTip = 'Specifies the number of normalized Adyen event entries created from this webhook request.';
        }
        field(10; "Retry Count"; Integer)
        {
            Caption = 'Retry Count';
            Editable = false;
            ToolTip = 'Specifies how many processing attempts for this webhook request have failed.';
        }
        field(11; "Last Error"; Text[2048])
        {
            Caption = 'Last Error';
            Editable = false;
            ToolTip = 'Specifies the most recent retryable processing error for this webhook request.';
        }
        field(12; "Processed At UTC"; DateTime)
        {
            Caption = 'Processed At UTC';
            Editable = false;
            ToolTip = 'Specifies the date and time in UTC when normalization of this webhook request completed.';
        }
        field(13; "Raw Content Purged"; Boolean)
        {
            Caption = 'Raw Content Purged';
            Editable = false;
            ToolTip = 'Specifies whether retention cleanup removed the raw JSON payload. Purged requests cannot be retried from Business Central.';
        }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(HashKey; "Payload Hash") { Unique = true; }
        key(FlowRunKey; "Flow Run ID") { }
        key(StatusKey; Status, "Received At UTC") { }
        key(ReceivedAtKey; "Received At UTC", "Entry No.") { }
    }

    trigger OnInsert()
    begin
        TestField("Payload Hash");
        if "Received At UTC" = 0DT then
            "Received At UTC" := CurrentDateTime();
        Status := Status::Received;
    end;
}
