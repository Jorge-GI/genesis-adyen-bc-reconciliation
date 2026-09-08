table 72001 "Adyen Merchant"
{
    Caption = 'Adyen Merchant';
    DataClassification = CustomerContent;
    LookupPageId = "Adyen Merchants";
    DrillDownPageId = "Adyen Merchants";

    fields
    {
        field(1; "Merchant Account"; Text[80]) { Caption = 'Merchant Account'; }
        field(2; Description; Text[100]) { Caption = 'Description'; }
        field(3; Enabled; Boolean) { Caption = 'Enabled'; }
        field(4; "Auto Post"; Boolean) { Caption = 'Auto Post'; }
        field(5; "Journal Template Name"; Code[10])
        {
            Caption = 'Journal Template Name';
            TableRelation = "Gen. Journal Template".Name;
        }
        field(6; "Journal Batch Name"; Code[10])
        {
            Caption = 'Automatic Journal Batch Name';
            TableRelation = "Gen. Journal Batch".Name where("Journal Template Name" = field("Journal Template Name"));
        }
        field(7; "Manual Journal Batch Name"; Code[10])
        {
            Caption = 'Manual Journal Batch Name';
            TableRelation = "Gen. Journal Batch".Name where("Journal Template Name" = field("Journal Template Name"));
        }
        field(8; "Clearing G/L Account No."; Code[20])
        {
            Caption = 'Clearing G/L Account No.';
            TableRelation = "G/L Account"."No.";
        }
        field(9; "Last Ready Report Date"; Date)
        {
            Caption = 'Last Ready Report Date';
            Editable = false;
        }
        field(10; "Report Overdue"; Boolean)
        {
            Caption = 'Report Overdue';
            Editable = false;
        }
        field(11; "Report Alert Message"; Text[250])
        {
            Caption = 'Report Alert Message';
            Editable = false;
        }
        field(12; "Latest Report Status"; Enum "Adyen Report Run Status")
        {
            Caption = 'Latest Report Status';
            Editable = false;
        }
        field(13; "Latest Report ID"; Text[100])
        {
            Caption = 'Latest Report ID';
            Editable = false;
        }
        field(14; "Report Status Updated At UTC"; DateTime)
        {
            Caption = 'Report Status Updated At UTC';
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Merchant Account") { Clustered = true; }
        key(EnabledKey; Enabled) { }
    }

    trigger OnInsert()
    begin
        TestField("Merchant Account");
        "Auto Post" := false;
    end;

    procedure ValidateForPosting()
    begin
        TestField(Enabled, true);
        TestField("Journal Template Name");
        TestField("Journal Batch Name");
        TestField("Manual Journal Batch Name");
        TestField("Clearing G/L Account No.");
    end;
}
