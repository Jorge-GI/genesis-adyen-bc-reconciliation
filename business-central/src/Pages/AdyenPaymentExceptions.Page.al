page 72014 "Adyen Payment Exceptions"
{
    PageType = List;
    Caption = 'Adyen Payment Exceptions';
    SourceTable = "Imported Adyen Payment";
    SourceTableView = where(Status = filter(Imported | Error | ReversalRequired));
    UsageCategory = Lists;
    ApplicationArea = All;
    layout
    {
        area(Content)
        {
            repeater(Exceptions)
            {
                field("PSP Reference"; Rec."PSP Reference") { ApplicationArea = All; Editable = false; }
                field("Shopper Reference"; Rec."Shopper Reference") { ApplicationArea = All; Editable = false; }
                field("Resolved Customer No."; Rec."Resolved Customer No.") { ApplicationArea = All; }
                field(Amount; Rec.Amount) { ApplicationArea = All; Editable = false; }
                field("Currency Code"; Rec."Currency Code") { ApplicationArea = All; Editable = false; }
                field(Status; Rec.Status) { ApplicationArea = All; Editable = false; }
                field("Match Result"; Rec."Match Result") { ApplicationArea = All; Editable = false; }
                field("Report Status"; Rec."Report Status") { ApplicationArea = All; Editable = false; }
                field("Exception Message"; Rec."Exception Message") { ApplicationArea = All; Editable = false; }
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
                    ManualJournal: Codeunit "Adyen Manual Journal Mgt.";
                begin
                    ManualJournal.CreateDraft(Rec, GenJournalLine);
                    Page.Run(Page::"Payment Journal", GenJournalLine);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
