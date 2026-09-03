table 72002 "Imported Adyen Payment"
{
    Caption = 'Imported Adyen Payment';
    DataClassification = CustomerContent;
    LookupPageId = "Imported Adyen Payments";
    DrillDownPageId = "Imported Adyen Payments";

    fields
    {
        field(1; "PSP Reference"; Code[50]) { Caption = 'PSP Reference'; }
        field(2; "Merchant Reference"; Text[80]) { Caption = 'Merchant Reference'; }
        field(3; "Shopper Reference"; Text[250]) { Caption = 'Shopper Reference'; Editable = false; }
        field(4; "Resolved Customer No."; Code[20]) { Caption = 'Resolved Customer No.'; TableRelation = Customer."No."; }
        field(5; "Payment Method"; Code[50]) { Caption = 'Payment Method'; }
        field(6; "Currency Code"; Code[10]) { Caption = 'Currency Code'; TableRelation = Currency.Code; }
        field(7; Amount; Decimal) { Caption = 'Amount'; DecimalPlaces = 0 : 5; }
        field(8; "Event Date-Time"; DateTime) { Caption = 'Event Date-Time'; }
        field(9; "Latest Event At UTC"; DateTime) { Caption = 'Latest Event At UTC'; }
        field(10; "Latest Logical Event Key"; Text[250]) { Caption = 'Latest Logical Event Key'; DataClassification = SystemMetadata; }
        field(11; "Origin Source"; Enum "Adyen Source") { Caption = 'Origin Source'; }
        field(12; Status; Enum "Adyen Payment Status") { Caption = 'Status'; }
        field(13; "Status Before Manual"; Enum "Adyen Payment Status") { Caption = 'Status Before Manual'; Editable = false; }
        field(14; "Match Result"; Enum "Adyen Match Result") { Caption = 'Match Result'; }
        field(15; "Report Status"; Enum "Adyen Report Status") { Caption = 'Report Status'; }
        field(16; "Matched Invoice Entry No."; Integer) { Caption = 'Matched Invoice Entry No.'; TableRelation = "Cust. Ledger Entry"."Entry No."; }
        field(17; "Posted Payment Entry No."; Integer) { Caption = 'Posted Payment Entry No.'; TableRelation = "Cust. Ledger Entry"."Entry No."; }
        field(18; "Manual Journal Template"; Code[10]) { Caption = 'Manual Journal Template'; }
        field(19; "Manual Journal Batch"; Code[10]) { Caption = 'Manual Journal Batch'; }
        field(20; "Manual Journal Line No."; Integer) { Caption = 'Manual Journal Line No.'; }
        field(21; "Exception Message"; Text[2048]) { Caption = 'Exception Message'; }
        field(22; Backfilled; Boolean) { Caption = 'Backfilled from report'; }
        field(23; "Created At UTC"; DateTime) { Caption = 'Created At UTC'; Editable = false; }
        field(24; "Modified At UTC"; DateTime) { Caption = 'Modified At UTC'; Editable = false; }
    }

    keys
    {
        key(PK; "PSP Reference") { Clustered = true; }
        key(StatusKey; Status, "Report Status") { }
        key(CustomerKey; "Resolved Customer No.", Status) { }
    }

    trigger OnInsert()
    begin
        TestField("PSP Reference");
        "Created At UTC" := CurrentDateTime();
        "Modified At UTC" := "Created At UTC";
    end;

    trigger OnModify()
    begin
        "Modified At UTC" := CurrentDateTime();
    end;
}
