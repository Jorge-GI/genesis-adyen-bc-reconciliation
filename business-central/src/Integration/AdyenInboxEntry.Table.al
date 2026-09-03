table 72001 "Adyen Inbox Entry"
{
    Caption = 'Adyen Inbox Entry';
    DataClassification = CustomerContent;
    LookupPageId = "Adyen Inbox Entries";
    DrillDownPageId = "Adyen Inbox Entries";

    fields
    {
        field(1; "Transport ID"; Code[64]) { Caption = 'Transport ID'; DataClassification = SystemMetadata; }
        field(2; "Logical Event Key"; Text[250]) { Caption = 'Logical Event Key'; DataClassification = SystemMetadata; }
        field(3; Source; Enum "Adyen Source") { Caption = 'Source'; }
        field(4; "Message Type"; Text[50]) { Caption = 'Message Type'; }
        field(5; "Occurred At UTC"; DateTime) { Caption = 'Occurred At UTC'; }
        field(6; "Received At UTC"; DateTime) { Caption = 'Received At UTC'; }
        field(7; "Payload Hash"; Code[64]) { Caption = 'Payload Hash'; DataClassification = SystemMetadata; }
        field(8; "Merchant Account"; Text[80]) { Caption = 'Merchant Account'; }
        field(9; Environment; Enum "Adyen Environment") { Caption = 'Environment'; }
        field(10; "PSP Reference"; Text[50]) { Caption = 'PSP Reference'; }
        field(11; "Original PSP Reference"; Text[50]) { Caption = 'Original PSP Reference'; }
        field(12; "Merchant Reference"; Text[80]) { Caption = 'Merchant Reference'; }
        field(13; "Shopper Reference"; Text[250]) { Caption = 'Shopper Reference'; }
        field(14; "Payment Method"; Code[50]) { Caption = 'Payment Method'; }
        field(15; "Success Provided"; Boolean) { Caption = 'Success Provided'; }
        field(16; Success; Boolean) { Caption = 'Success'; }
        field(17; "Currency Code"; Code[10]) { Caption = 'Currency Code'; }
        field(18; Amount; Decimal) { Caption = 'Amount'; DecimalPlaces = 0 : 5; }
        field(19; "Report Run ID"; Code[100]) { Caption = 'Report Run ID'; TableRelation = "Adyen Report Run"."External Report ID"; }
        field(20; "Report Row Identity"; Code[64]) { Caption = 'Report Row Identity'; DataClassification = SystemMetadata; }
        field(21; "Raw Archive Reference"; Text[2048]) { Caption = 'Raw Archive Reference'; ExtendedDatatype = URL; }
        field(22; Status; Enum "Adyen Inbox Status") { Caption = 'Status'; }
        field(23; "Retry Count"; Integer) { Caption = 'Retry Count'; Editable = false; }
        field(24; "Last Error"; Text[2048]) { Caption = 'Last Error'; Editable = false; }
        field(25; "Processed At UTC"; DateTime) { Caption = 'Processed At UTC'; Editable = false; }
    }

    keys
    {
        key(PK; "Transport ID") { Clustered = true; }
        key(StatusKey; Status, "Occurred At UTC") { }
        key(LogicalKey; "Logical Event Key", "Occurred At UTC") { }
        key(ReportKey; "Report Run ID", Status) { }
    }

    trigger OnInsert()
    begin
        TestField("Transport ID");
        TestField("Logical Event Key");
        TestField("Message Type");
        TestField("Merchant Account");
        TestField("PSP Reference");
        if "Received At UTC" = 0DT then
            "Received At UTC" := CurrentDateTime();
        Status := Status::Received;
    end;
}
