table 72001 "Adyen Merchant"
{
    Caption = 'Adyen Merchant';
    DataClassification = CustomerContent;
    LookupPageId = "Adyen Merchants";
    DrillDownPageId = "Adyen Merchants";

    fields
    {
        field(1; "Merchant Account"; Text[80])
        {
            Caption = 'Merchant Account';
            ToolTip = 'Specifies the exact, case-sensitive Adyen merchant account accepted for this company.';
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
            ToolTip = 'Specifies a recognizable description for the Adyen merchant account.';
        }
        field(3; Enabled; Boolean)
        {
            Caption = 'Enabled';
            ToolTip = 'Specifies whether webhook and report data for this merchant account may be accepted and processed.';
        }
        field(4; "Auto Post"; Boolean)
        {
            Caption = 'Auto Post';
            ToolTip = 'Specifies whether uniquely matched, eligible payments for this merchant may be posted and applied automatically. Leave this off until validation is complete.';
        }
        field(5; "Journal Template Name"; Code[10])
        {
            Caption = 'Journal Template Name';
            TableRelation = "Gen. Journal Template".Name;
            ToolTip = 'Specifies the general journal template used for automatic and manual Adyen payment journals.';
        }
        field(6; "Journal Batch Name"; Code[10])
        {
            Caption = 'Automatic Journal Batch Name';
            TableRelation = "Gen. Journal Batch".Name where("Journal Template Name" = field("Journal Template Name"));
            ToolTip = 'Specifies the journal batch used when Adyen payments are posted and applied automatically.';
        }
        field(7; "Manual Journal Batch Name"; Code[10])
        {
            Caption = 'Manual Journal Batch Name';
            TableRelation = "Gen. Journal Batch".Name where("Journal Template Name" = field("Journal Template Name"));
            ToolTip = 'Specifies the journal batch where draft lines are created for payments that require manual reconciliation.';
        }
        field(8; "Clearing G/L Account No."; Code[20])
        {
            Caption = 'Clearing G/L Account No.';
            TableRelation = "G/L Account"."No.";
            ToolTip = 'Specifies the clearing G/L account used as the balancing account for Adyen payment journal lines.';
        }
        field(9; "Last Ready Report Date"; Date)
        {
            Caption = 'Last Ready Report Date';
            Editable = false;
            ToolTip = 'Specifies the most recent report date for which this merchant had a report ready for reconciliation.';
        }
        field(10; "Report Overdue"; Boolean)
        {
            Caption = 'Report Overdue';
            Editable = false;
            ToolTip = 'Specifies whether the expected daily report for this merchant was still missing after the configured deadline.';
        }
        field(11; "Report Alert Message"; Text[250])
        {
            Caption = 'Report Alert Message';
            Editable = false;
            ToolTip = 'Specifies the current overdue-report warning for this merchant, including the expected report date.';
        }
        field(12; "Latest Report Status"; Enum "Adyen Report Run Status")
        {
            Caption = 'Latest Report Status';
            Editable = false;
            ToolTip = 'Specifies the current processing status of the latest report received for this merchant.';
        }
        field(13; "Latest Report ID"; Text[100])
        {
            Caption = 'Latest Report ID';
            Editable = false;
            ToolTip = 'Specifies the Adyen identifier of the latest report received for this merchant.';
        }
        field(14; "Report Status Updated At UTC"; DateTime)
        {
            Caption = 'Report Status Updated At UTC';
            Editable = false;
            ToolTip = 'Specifies the date and time in UTC when the latest report status for this merchant was updated.';
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
