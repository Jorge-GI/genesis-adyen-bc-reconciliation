table 72003 "Adyen Event Entry"
{
    Caption = 'Adyen Event Entry';
    DataClassification = CustomerContent;
    LookupPageId = "Adyen Event Entries";
    DrillDownPageId = "Adyen Event Entries";

    fields
    {
        field(1; "Transport ID"; Code[64]) { Caption = 'Transport ID'; DataClassification = SystemMetadata; }
        field(2; "Logical Event Key"; Text[250]) { Caption = 'Logical Event Key'; DataClassification = SystemMetadata; }
        field(3; Source; Enum "Adyen Source") { Caption = 'Source'; }
        field(4; "Webhook Request Entry No."; BigInteger) { Caption = 'Webhook Request Entry No.'; }
        field(5; "Report Run Entry No."; BigInteger) { Caption = 'Report Run Entry No.'; }
        field(6; "Report Row No."; Integer) { Caption = 'Report Row No.'; }
        field(7; "Report Row Identity"; Code[64]) { Caption = 'Report Row Identity'; DataClassification = SystemMetadata; }
        field(8; "Message Type"; Text[50]) { Caption = 'Message Type'; }
        field(9; "Occurred At UTC"; DateTime) { Caption = 'Occurred At UTC'; }
        field(10; "Received At UTC"; DateTime) { Caption = 'Received At UTC'; }
        field(11; "Payload Hash"; Code[64]) { Caption = 'Payload Hash'; DataClassification = SystemMetadata; }
        field(12; "Merchant Account"; Text[80]) { Caption = 'Merchant Account'; TableRelation = "Adyen Merchant"."Merchant Account"; }
        field(13; "PSP Reference"; Text[50]) { Caption = 'PSP Reference'; }
        field(14; "Original PSP Reference"; Text[50]) { Caption = 'Original PSP Reference'; }
        field(15; "Merchant Reference"; Text[80]) { Caption = 'Merchant Reference'; }
        field(16; "Shopper Reference"; Text[250]) { Caption = 'Shopper Reference'; }
        field(17; "Payment Method"; Code[50]) { Caption = 'Payment Method'; }
        field(18; "Success Provided"; Boolean) { Caption = 'Success Provided'; }
        field(19; Success; Boolean) { Caption = 'Success'; }
        field(20; "Currency Code"; Code[10]) { Caption = 'Currency Code'; }
        field(21; Amount; Decimal) { Caption = 'Amount'; DecimalPlaces = 0 : 5; }
        field(22; Reason; Text[2048]) { Caption = 'Reason'; }
        field(23; Status; Enum "Adyen Process Status") { Caption = 'Status'; }
        field(24; "Retry Count"; Integer) { Caption = 'Retry Count'; Editable = false; }
        field(25; "Last Error"; Text[2048]) { Caption = 'Last Error'; Editable = false; }
        field(26; "Processed At UTC"; DateTime) { Caption = 'Processed At UTC'; Editable = false; }
        field(27; "External Report ID"; Text[100]) { Caption = 'External Report ID'; }
    }

    keys
    {
        key(PK; "Transport ID") { Clustered = true; }
        key(StatusKey; Status, "Occurred At UTC") { }
        key(LogicalKey; "Logical Event Key", "Occurred At UTC") { }
        key(RequestKey; "Webhook Request Entry No.") { }
        key(ReportKey; "Report Run Entry No.", Status) { }
    }

    trigger OnInsert()
    begin
        TestField("Transport ID");
        TestField("Logical Event Key");
        TestField("Message Type");
        TestField("Merchant Account");
        TestField("PSP Reference");
        Status := Status::Received;
    end;
}
