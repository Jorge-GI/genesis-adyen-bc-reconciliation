page 72012 "Adyen Inbox Entries"
{
    PageType = List;
    Caption = 'Adyen Inbox Entries';
    SourceTable = "Adyen Inbox Entry";
    UsageCategory = History;
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field("Received At UTC"; Rec."Received At UTC") { ApplicationArea = All; }
                field(Source; Rec.Source) { ApplicationArea = All; }
                field("Message Type"; Rec."Message Type") { ApplicationArea = All; }
                field("PSP Reference"; Rec."PSP Reference") { ApplicationArea = All; }
                field("Original PSP Reference"; Rec."Original PSP Reference") { ApplicationArea = All; }
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
                end;
            }
        }
    }
}
