table 72004 "Adyen Report Run"
{
    Caption = 'Adyen Report Run';
    DataClassification = CustomerContent;
    LookupPageId = "Adyen Report Runs";
    DrillDownPageId = "Adyen Report Runs";

    fields
    {
        field(1; "Entry No."; BigInteger)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the internal entry number assigned to the report run.';
        }
        field(2; "Merchant Account"; Text[80])
        {
            Caption = 'Merchant Account';
            TableRelation = "Adyen Merchant"."Merchant Account";
            ToolTip = 'Specifies the Adyen merchant account for which the report was requested.';
        }
        field(3; "External Report ID"; Text[100])
        {
            Caption = 'External Report ID';
            ToolTip = 'Specifies the report identifier supplied by Adyen.';
        }
        field(4; "Download URL"; Text[2048])
        {
            Caption = 'Download URL';
            ExtendedDatatype = URL;
            ToolTip = 'Specifies the HTTPS location supplied by Adyen for the report download. The host must match the configured allowlist.';
        }
        field(5; Content; Blob)
        {
            Caption = 'Report Content';
            ToolTip = 'Specifies the original downloaded report content retained for retry and audit.';
        }
        field(6; "File Hash"; Code[64])
        {
            Caption = 'File Hash';
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the SHA-256 hash of the downloaded report file.';
        }
        field(7; "Report Date"; Date)
        {
            Caption = 'Report Date';
            ToolTip = 'Specifies the accounting date parsed from the Adyen report filename.';
        }
        field(8; Status; Enum "Adyen Report Run Status")
        {
            Caption = 'Status';
            ToolTip = 'Specifies the current download, loading, reconciliation, completion, or error state of the report run.';
        }
        field(9; "Total Row Count"; Integer)
        {
            Caption = 'Total Row Count';
            MinValue = 0;
            ToolTip = 'Specifies the total number of data rows read from the report.';
        }
        field(10; "Relevant Row Count"; Integer)
        {
            Caption = 'Relevant Row Count';
            MinValue = 0;
            ToolTip = 'Specifies the number of report rows whose record types are relevant to this reconciliation process.';
        }
        field(11; "Loaded Row Count"; Integer)
        {
            Caption = 'Loaded Row Count';
            MinValue = 0;
            ToolTip = 'Specifies the number of relevant report rows successfully normalized as Adyen events.';
        }
        field(12; "Retry Count"; Integer)
        {
            Caption = 'Retry Count';
            Editable = false;
            ToolTip = 'Specifies how many processing attempts for this report run have failed.';
        }
        field(13; "Last Error"; Text[2048])
        {
            Caption = 'Last Error';
            Editable = false;
            ToolTip = 'Specifies the most recent retryable download, loading, or reconciliation error for this report run.';
        }
        field(14; "Requested At UTC"; DateTime)
        {
            Caption = 'Requested At UTC';
            Editable = false;
            ToolTip = 'Specifies the date and time in UTC when the report run was first requested.';
        }
        field(15; "Ready At UTC"; DateTime)
        {
            Caption = 'Ready At UTC';
            Editable = false;
            ToolTip = 'Specifies the date and time in UTC when all relevant report rows had been loaded and the report became ready for reconciliation.';
        }
        field(16; "Processed At UTC"; DateTime)
        {
            Caption = 'Processed At UTC';
            Editable = false;
            ToolTip = 'Specifies the date and time in UTC when reconciliation of this report run completed.';
        }
        field(17; "Content Purged"; Boolean)
        {
            Caption = 'Content Purged';
            Editable = false;
            ToolTip = 'Specifies whether retention cleanup removed the downloaded CSV content. A retry requires a fresh download from the retained URL.';
        }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(ExternalKey; "Merchant Account", "External Report ID") { Unique = true; }
        key(StatusKey; Status, "Requested At UTC") { }
        key(HashKey; "File Hash") { }
        key(RequestedAtKey; "Requested At UTC", "Entry No.") { }
    }

    trigger OnInsert()
    begin
        TestField("Merchant Account");
        TestField("External Report ID");
        TestField("Download URL");
        "Requested At UTC" := CurrentDateTime();
        Status := Status::Requested;
        UpdateMerchantReportStatus();
    end;

    trigger OnModify()
    begin
        if Status <> xRec.Status then
            UpdateMerchantReportStatus();
    end;

    local procedure UpdateMerchantReportStatus()
    var
        Merchant: Record "Adyen Merchant";
    begin
        if not Merchant.Get("Merchant Account") then
            exit;
        Merchant."Latest Report ID" := "External Report ID";
        Merchant."Latest Report Status" := Status;
        Merchant."Report Status Updated At UTC" := CurrentDateTime();
        Merchant.Modify(true);
    end;
}
