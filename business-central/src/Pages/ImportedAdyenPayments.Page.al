page 72014 "Imported Adyen Payments"
{
    PageType = List;
    Caption = 'Imported Adyen Payments';
    SourceTable = "Imported Adyen Payment";
    UsageCategory = Lists;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Payments)
            {
                field("Merchant Account"; Rec."Merchant Account") { ApplicationArea = All; }
                field("PSP Reference"; Rec."PSP Reference") { ApplicationArea = All; }
                field("Merchant Reference"; Rec."Merchant Reference") { ApplicationArea = All; }
                field("Shopper Reference"; Rec."Shopper Reference") { ApplicationArea = All; }
                field("Resolved Customer No."; Rec."Resolved Customer No.") { ApplicationArea = All; }
                field("Payment Method"; Rec."Payment Method") { ApplicationArea = All; }
                field(Amount; Rec.Amount) { ApplicationArea = All; }
                field("Currency Code"; Rec."Currency Code") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("Match Result"; Rec."Match Result") { ApplicationArea = All; }
                field("Report Status"; Rec."Report Status") { ApplicationArea = All; }
                field(Backfilled; Rec.Backfilled) { ApplicationArea = All; }
                field("Exception Message"; Rec."Exception Message") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ReevaluateMatch)
            {
                Caption = 'Re-evaluate Match';
                ApplicationArea = All;
                Image = Refresh;
                Enabled = (Rec."Posted Payment Entry No." = 0) and
                          (Rec.Status <> Rec.Status::ManualJournalCreated) and
                          (Rec.Status <> Rec.Status::ReversalRequired) and
                          (Rec.Status <> Rec.Status::DataConflict);

                trigger OnAction()
                var
                    Matcher: Codeunit "Adyen Invoice Matcher";
                begin
                    Matcher.Match(Rec);
                    if Rec."Match Result" = Rec."Match Result"::UniqueExact then
                        Rec.Status := Rec.Status::ReadyToPost
                    else
                        Rec.Status := Rec.Status::Imported;
                    Rec.Modify(true);
                    CurrPage.Update(false);
                end;
            }
            action(PostExactMatch)
            {
                Caption = 'Post Exact Match';
                ApplicationArea = All;
                Image = Post;
                Enabled = (Rec.Status = Rec.Status::ReadyToPost) and
                          (Rec."Match Result" = Rec."Match Result"::UniqueExact) and
                          (Rec."Posted Payment Entry No." = 0);

                trigger OnAction()
                var
                    Poster: Codeunit "Adyen Payment Poster";
                begin
                    Poster.PostAndApply(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(CreateManualJournal)
            {
                Caption = 'Create Manual Journal Line';
                ApplicationArea = All;
                Image = Journal;
                Enabled = ((Rec.Status = Rec.Status::Imported) or (Rec.Status = Rec.Status::Error) or
                          (Rec.Status = Rec.Status::ReadyToPost)) and (Rec."Posted Payment Entry No." = 0);

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
            action(OpenPostedPayment)
            {
                Caption = 'Open Posted Payment';
                ApplicationArea = All;
                Image = CustomerLedger;
                Enabled = Rec."Posted Payment Entry No." <> 0;

                trigger OnAction()
                var
                    CustLedgerEntry: Record "Cust. Ledger Entry";
                begin
                    CustLedgerEntry.Get(Rec."Posted Payment Entry No.");
                    Page.Run(Page::"Customer Ledger Entries", CustLedgerEntry);
                end;
            }
        }
    }
}
