table 72003 "Adyen Report Run"
{
    Caption = 'Adyen Report Run';
    DataClassification = CustomerContent;
    LookupPageId = "Adyen Report Runs";

    fields
    {
        field(1; "External Report ID"; Code[100]) { Caption = 'External Report ID'; }
        field(2; "File Hash"; Code[64]) { Caption = 'File Hash'; DataClassification = SystemMetadata; }
        field(3; "Report Date"; Date) { Caption = 'Report Date'; }
        field(4; Status; Enum "Adyen Report Run Status") { Caption = 'Status'; }
        field(5; "Total Row Count"; Integer) { Caption = 'Total Row Count'; MinValue = 0; }
        field(6; "Relevant Row Count"; Integer) { Caption = 'Relevant Row Count'; MinValue = 0; }
        field(7; "Loaded Row Count"; Integer) { Caption = 'Loaded Row Count'; MinValue = 0; }
        field(8; "Archive Reference"; Text[2048]) { Caption = 'Archive Reference'; ExtendedDatatype = URL; }
        field(9; "Error Message"; Text[2048]) { Caption = 'Error Message'; }
        field(10; "Started At UTC"; DateTime) { Caption = 'Started At UTC'; Editable = false; }
        field(11; "Ready At UTC"; DateTime) { Caption = 'Ready At UTC'; Editable = false; }
        field(12; "Processed At UTC"; DateTime) { Caption = 'Processed At UTC'; Editable = false; }
    }

    keys
    {
        key(PK; "External Report ID") { Clustered = true; }
        key(StatusKey; Status, "Report Date") { }
        key(HashKey; "File Hash") { }
    }

    trigger OnInsert()
    begin
        TestField("External Report ID");
        TestField("File Hash");
        "Started At UTC" := CurrentDateTime();
        Status := Status::Loading;
    end;
}
