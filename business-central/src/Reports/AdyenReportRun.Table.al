table 72004 "Adyen Report Run"
{
    Caption = 'Adyen Report Run';
    DataClassification = CustomerContent;
    LookupPageId = "Adyen Report Runs";
    DrillDownPageId = "Adyen Report Runs";

    fields
    {
        field(1; "Entry No."; BigInteger) { Caption = 'Entry No.'; AutoIncrement = true; DataClassification = SystemMetadata; }
        field(2; "Merchant Account"; Text[80]) { Caption = 'Merchant Account'; TableRelation = "Adyen Merchant"."Merchant Account"; }
        field(3; "External Report ID"; Text[100]) { Caption = 'External Report ID'; }
        field(4; "Download URL"; Text[2048]) { Caption = 'Download URL'; ExtendedDatatype = URL; }
        field(5; Content; Blob) { Caption = 'Report Content'; }
        field(6; "File Hash"; Code[64]) { Caption = 'File Hash'; DataClassification = SystemMetadata; }
        field(7; "Report Date"; Date) { Caption = 'Report Date'; }
        field(8; Status; Enum "Adyen Report Run Status") { Caption = 'Status'; }
        field(9; "Total Row Count"; Integer) { Caption = 'Total Row Count'; MinValue = 0; }
        field(10; "Relevant Row Count"; Integer) { Caption = 'Relevant Row Count'; MinValue = 0; }
        field(11; "Loaded Row Count"; Integer) { Caption = 'Loaded Row Count'; MinValue = 0; }
        field(12; "Retry Count"; Integer) { Caption = 'Retry Count'; Editable = false; }
        field(13; "Last Error"; Text[2048]) { Caption = 'Last Error'; Editable = false; }
        field(14; "Requested At UTC"; DateTime) { Caption = 'Requested At UTC'; Editable = false; }
        field(15; "Ready At UTC"; DateTime) { Caption = 'Ready At UTC'; Editable = false; }
        field(16; "Processed At UTC"; DateTime) { Caption = 'Processed At UTC'; Editable = false; }
        field(17; "Content Purged"; Boolean) { Caption = 'Content Purged'; Editable = false; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(ExternalKey; "Merchant Account", "External Report ID") { Unique = true; }
        key(StatusKey; Status, "Requested At UTC") { }
        key(HashKey; "File Hash") { }
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
