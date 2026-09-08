page 72013 "Adyen Event Entries"
{
    PageType = List;
    Caption = 'Adyen Event Entries';
    SourceTable = "Adyen Event Entry";
    UsageCategory = History;
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Events)
            {
                field("Occurred At UTC"; Rec."Occurred At UTC") { ApplicationArea = All; }
                field(Source; Rec.Source) { ApplicationArea = All; }
                field("Merchant Account"; Rec."Merchant Account") { ApplicationArea = All; }
                field("Message Type"; Rec."Message Type") { ApplicationArea = All; }
                field("PSP Reference"; Rec."PSP Reference") { ApplicationArea = All; }
                field("Original PSP Reference"; Rec."Original PSP Reference") { ApplicationArea = All; }
                field("External Report ID"; Rec."External Report ID") { ApplicationArea = All; }
                field("Shopper Reference"; Rec."Shopper Reference") { ApplicationArea = All; }
                field(Amount; Rec.Amount) { ApplicationArea = All; }
                field("Currency Code"; Rec."Currency Code") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("Retry Count"; Rec."Retry Count") { ApplicationArea = All; }
                field("Last Error"; Rec."Last Error") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Retry)
            {
                Caption = 'Retry';
                ApplicationArea = All;
                Image = Refresh;
                Enabled = Rec.Status = Rec.Status::Error;

                trigger OnAction()
                begin
                    Rec.Status := Rec.Status::Received;
                    Rec."Last Error" := '';
                    Rec.Modify(true);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
