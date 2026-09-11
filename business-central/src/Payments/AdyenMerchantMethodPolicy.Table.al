table 72007 "Adyen Merchant Method Policy"
{
    Caption = 'Adyen Payment Method Policy';
    DataClassification = CustomerContent;
    LookupPageId = "Adyen Payment Method Policies";

    fields
    {
        field(1; "Merchant Account"; Text[80])
        {
            Caption = 'Merchant Account';
            TableRelation = "Adyen Merchant"."Merchant Account";
            ToolTip = 'Specifies the Adyen merchant account to which this payment-method policy applies.';
        }
        field(2; "Payment Method"; Code[50])
        {
            Caption = 'Payment Method';
            ToolTip = 'Specifies the normalized Adyen payment method or report variant governed by this policy.';
        }
        field(3; Description; Text[100])
        {
            Caption = 'Description';
            ToolTip = 'Specifies a recognizable description of the payment method.';
        }
        field(4; "Enabled for Auto Post"; Boolean)
        {
            Caption = 'Enabled for Auto Post';
            ToolTip = 'Specifies whether payments using this method and merchant may enter the automatic matching and posting path.';
        }
        field(5; "Verified At UTC"; DateTime)
        {
            Caption = 'Verified At UTC';
            Editable = false;
            ToolTip = 'Specifies the date and time in UTC when this policy was created or last changed.';
        }
    }

    keys
    {
        key(PK; "Merchant Account", "Payment Method") { Clustered = true; }
    }

    trigger OnInsert()
    begin
        TestField("Merchant Account");
        TestField("Payment Method");
        "Verified At UTC" := CurrentDateTime();
    end;

    trigger OnModify()
    begin
        "Verified At UTC" := CurrentDateTime();
    end;
}
