table 72006 "Adyen Payment Method Policy"
{
    Caption = 'Adyen Payment Method Policy';
    DataClassification = CustomerContent;
    LookupPageId = "Adyen Payment Method Policies";

    fields
    {
        field(1; "Payment Method"; Code[50]) { Caption = 'Payment Method'; }
        field(2; Description; Text[100]) { Caption = 'Description'; }
        field(3; "Enabled for Auto Post"; Boolean) { Caption = 'Enabled for Auto Post'; }
        field(4; "Verified At UTC"; DateTime) { Caption = 'Verified At UTC'; Editable = false; }
    }

    keys
    {
        key(PK; "Payment Method") { Clustered = true; }
    }

    trigger OnInsert()
    begin
        "Verified At UTC" := CurrentDateTime();
    end;

    trigger OnModify()
    begin
        "Verified At UTC" := CurrentDateTime();
    end;
}
