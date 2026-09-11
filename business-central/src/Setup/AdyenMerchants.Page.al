page 72011 "Adyen Merchants"
{
    PageType = List;
    Caption = 'Adyen Merchants';
    SourceTable = "Adyen Merchant";
    UsageCategory = Administration;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Merchants)
            {
                field("Merchant Account"; Rec."Merchant Account") { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field(Enabled; Rec.Enabled) { ApplicationArea = All; }
                field("Auto Post"; Rec."Auto Post") { ApplicationArea = All; }
                field("Journal Template Name"; Rec."Journal Template Name") { ApplicationArea = All; }
                field("Journal Batch Name"; Rec."Journal Batch Name") { ApplicationArea = All; }
                field("Manual Journal Batch Name"; Rec."Manual Journal Batch Name") { ApplicationArea = All; }
                field("Clearing G/L Account No."; Rec."Clearing G/L Account No.") { ApplicationArea = All; }
                field("Last Ready Report Date"; Rec."Last Ready Report Date") { ApplicationArea = All; }
                field("Latest Report ID"; Rec."Latest Report ID") { ApplicationArea = All; }
                field("Latest Report Status"; Rec."Latest Report Status") { ApplicationArea = All; }
                field("Report Status Updated At UTC"; Rec."Report Status Updated At UTC") { ApplicationArea = All; }
                field("Report Overdue"; Rec."Report Overdue") { ApplicationArea = All; }
                field("Report Alert Message"; Rec."Report Alert Message") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(PaymentMethodPolicies)
            {
                Caption = 'Payment Method Policies';
                ApplicationArea = All;
                Image = Payment;
                RunObject = page "Adyen Payment Method Policies";
                RunPageLink = "Merchant Account" = field("Merchant Account");
                ToolTip = 'View or configure the payment methods that are eligible for automatic matching and posting for the selected merchant.';
            }
        }
    }
}
