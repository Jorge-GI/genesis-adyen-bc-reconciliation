page 72015 "Adyen Payment Method Policies"
{
    PageType = List;
    Caption = 'Adyen Payment Method Policies';
    SourceTable = "Adyen Payment Method Policy";
    UsageCategory = Administration;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Policies)
            {
                field("Payment Method"; Rec."Payment Method") { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field("Enabled for Auto Post"; Rec."Enabled for Auto Post") { ApplicationArea = All; }
                field("Verified At UTC"; Rec."Verified At UTC") { ApplicationArea = All; }
            }
        }
    }
}
