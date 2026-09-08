page 72015 "Adyen Payment Exceptions"
{
    PageType = List;
    Caption = 'Adyen Payment Exceptions';
    SourceTable = "Imported Adyen Payment";
    SourceTableView = where(Status = filter(Imported | Error | ReversalRequired | DataConflict));
    UsageCategory = Lists;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Exceptions)
            {
                field("Merchant Account"; Rec."Merchant Account") { ApplicationArea = All; }
                field("PSP Reference"; Rec."PSP Reference") { ApplicationArea = All; }
                field("Shopper Reference"; Rec."Shopper Reference") { ApplicationArea = All; }
                field("Resolved Customer No."; Rec."Resolved Customer No.") { ApplicationArea = All; }
                field(Amount; Rec.Amount) { ApplicationArea = All; }
                field("Currency Code"; Rec."Currency Code") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("Match Result"; Rec."Match Result") { ApplicationArea = All; }
                field("Report Status"; Rec."Report Status") { ApplicationArea = All; }
                field("Exception Message"; Rec."Exception Message") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CreateManualJournal)
            {
                Caption = 'Create Manual Journal Line';
                ApplicationArea = All;
                Image = Journal;
                Enabled = (Rec.Status = Rec.Status::Imported) or (Rec.Status = Rec.Status::Error);

                trigger OnAction()
                var
                    GenJournalLine: Record "Gen. Journal Line";
                    ManualJournal: Codeunit "Adyen Manual Journal";
                begin
                    ManualJournal.CreateDraft(Rec, GenJournalLine);
                    Page.Run(Page::"Payment Journal", GenJournalLine);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
