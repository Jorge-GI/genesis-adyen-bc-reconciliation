page 72013 "Adyen Event Entries"
{
    PageType = List;
    Caption = 'Adyen Event Entries';
    SourceTable = "Adyen Event Entry";
    SourceTableView = sorting("Occurred At UTC", "Transport ID") order(descending);
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
                field("Payment PSP Reference"; Rec."Payment PSP Reference") { ApplicationArea = All; }
                field("External Report ID"; Rec."External Report ID") { ApplicationArea = All; }
                field("Shopper Reference"; Rec."Shopper Reference") { ApplicationArea = All; }
                field(Amount; Rec.Amount) { ApplicationArea = All; }
                field("Currency Code"; Rec."Currency Code") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("Adyen Reason"; Rec.Reason)
                {
                    ApplicationArea = All;
                    Caption = 'Adyen Reason';
                }
                field("Disposition Reason"; Rec."Disposition Reason") { ApplicationArea = All; }
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
                ToolTip = 'Return the selected errored event to the queue so lifecycle, matching, and reconciliation processing can run again.';
                Enabled = Rec.Status = Rec.Status::Error;

                trigger OnAction()
                var
                    EventDisposition: Codeunit "Adyen Event Disposition";
                begin
                    Rec.Status := Rec.Status::Received;
                    Rec."Last Error" := '';
                    EventDisposition.ClearReason(Rec);
                    Rec.Modify(true);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
