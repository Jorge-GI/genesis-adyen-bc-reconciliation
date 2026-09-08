table 72005 "Imported Adyen Payment"
{
    Caption = 'Imported Adyen Payment';
    DataClassification = CustomerContent;
    LookupPageId = "Imported Adyen Payments";
    DrillDownPageId = "Imported Adyen Payments";

    fields
    {
        field(1; "Merchant Account"; Text[80]) { Caption = 'Merchant Account'; TableRelation = "Adyen Merchant"."Merchant Account"; Editable = false; }
        field(2; "PSP Reference"; Code[50]) { Caption = 'PSP Reference'; Editable = false; }
        field(3; "Merchant Reference"; Text[80]) { Caption = 'Merchant Reference'; Editable = false; }
        field(4; "Shopper Reference"; Text[250]) { Caption = 'Shopper Reference'; Editable = false; }
        field(5; "Resolved Customer No."; Code[20]) { Caption = 'Resolved Customer No.'; TableRelation = Customer."No."; }
        field(6; "Payment Method"; Code[50]) { Caption = 'Payment Method'; Editable = false; }
        field(7; "Currency Code"; Code[10]) { Caption = 'Currency Code'; TableRelation = Currency.Code; Editable = false; }
        field(8; Amount; Decimal) { Caption = 'Amount'; DecimalPlaces = 0 : 5; Editable = false; }
        field(9; "Event Date-Time"; DateTime) { Caption = 'Event Date-Time'; Editable = false; }
        field(10; "Latest Event At UTC"; DateTime) { Caption = 'Latest Event At UTC'; Editable = false; }
        field(11; "Latest Logical Event Key"; Text[250]) { Caption = 'Latest Logical Event Key'; DataClassification = SystemMetadata; Editable = false; }
        field(12; "Origin Source"; Enum "Adyen Source") { Caption = 'Origin Source'; Editable = false; }
        field(13; Status; Enum "Adyen Payment Status") { Caption = 'Status'; Editable = false; }
        field(14; "Status Before Manual"; Enum "Adyen Payment Status") { Caption = 'Status Before Manual'; Editable = false; }
        field(15; "Match Result"; Enum "Adyen Match Result") { Caption = 'Match Result'; Editable = false; }
        field(16; "Report Status"; Enum "Adyen Report Status") { Caption = 'Report Status'; Editable = false; }
        field(17; "Matched Invoice Entry No."; Integer) { Caption = 'Matched Invoice Entry No.'; TableRelation = "Cust. Ledger Entry"."Entry No."; Editable = false; }
        field(18; "Posted Payment Entry No."; Integer) { Caption = 'Posted Payment Entry No.'; TableRelation = "Cust. Ledger Entry"."Entry No."; Editable = false; }
        field(19; "Manual Journal Template"; Code[10]) { Caption = 'Manual Journal Template'; Editable = false; }
        field(20; "Manual Journal Batch"; Code[10]) { Caption = 'Manual Journal Batch'; Editable = false; }
        field(21; "Manual Journal Line No."; Integer) { Caption = 'Manual Journal Line No.'; Editable = false; }
        field(22; "Exception Message"; Text[2048]) { Caption = 'Exception Message'; Editable = false; }
        field(23; Backfilled; Boolean) { Caption = 'Backfilled from report'; Editable = false; }
        field(24; "Created At UTC"; DateTime) { Caption = 'Created At UTC'; Editable = false; }
        field(25; "Modified At UTC"; DateTime) { Caption = 'Modified At UTC'; Editable = false; }
    }

    keys
    {
        key(PK; "Merchant Account", "PSP Reference") { Clustered = true; }
        key(StatusKey; Status, "Report Status") { }
        key(CustomerKey; "Resolved Customer No.", Status) { }
    }

    trigger OnInsert()
    begin
        TestField("Merchant Account");
        TestField("PSP Reference");
        "Created At UTC" := CurrentDateTime();
        "Modified At UTC" := "Created At UTC";
    end;

    trigger OnModify()
    begin
        "Modified At UTC" := CurrentDateTime();
    end;
}
