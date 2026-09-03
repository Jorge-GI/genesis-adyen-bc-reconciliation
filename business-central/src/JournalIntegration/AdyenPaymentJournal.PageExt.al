pageextension 72000 "Adyen Payment Journal" extends "Payment Journal"
{
    layout
    {
        addafter("External Document No.")
        {
            field("Adyen Payment ID"; Rec."Adyen Payment ID")
            {
                ApplicationArea = All;
                Editable = false;
                Visible = false;
            }
        }
    }
}
