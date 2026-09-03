table 72000 "Adyen Setup"
{
    Caption = 'Adyen Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(2; Enabled; Boolean)
        {
            Caption = 'Enabled';
        }
        field(3; "Merchant Account"; Text[80])
        {
            Caption = 'Merchant Account';
        }
        field(4; Environment; Enum "Adyen Environment")
        {
            Caption = 'Environment';
        }
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
        field(9; "Auto Post"; Boolean)
        {
            Caption = 'Auto Post';
        }
        field(10; "Report Deadline"; Time)
        {
            Caption = 'Report Deadline';
        }
        field(11; "Last Ready Report Date"; Date)
        {
            Caption = 'Last Ready Report Date';
            Editable = false;
        }
        field(12; "Raw Retention Days"; Integer)
        {
            Caption = 'Raw Retention Days';
            MinValue = 1;
        }
        field(13; "Report Retention Months"; Integer)
        {
            Caption = 'Report Retention Months';
            MinValue = 1;
        }
        field(14; "Report Overdue"; Boolean)
        {
            Caption = 'Report Overdue';
            Editable = false;
        }
        field(15; "Report Alert Message"; Text[250])
        {
            Caption = 'Report Alert Message';
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }

    trigger OnInsert()
    begin
        if "Report Deadline" = 0T then
            "Report Deadline" := 120000T;
        if "Raw Retention Days" = 0 then
            "Raw Retention Days" := 90;
        if "Report Retention Months" = 0 then
            "Report Retention Months" := 13;
    end;

    procedure GetRecordOnce()
    begin
        if not Get('SETUP') then begin
            Init();
            "Primary Key" := 'SETUP';
            Insert(true);
        end;
    end;

    procedure ValidateForProcessing()
    begin
        TestField(Enabled, true);
        TestField("Merchant Account");
        TestField("Journal Template Name");
        TestField("Journal Batch Name");
        TestField("Manual Journal Batch Name");
        TestField("Clearing G/L Account No.");
    end;
}
