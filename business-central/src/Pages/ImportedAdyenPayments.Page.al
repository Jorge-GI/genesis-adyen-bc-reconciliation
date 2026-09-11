page 72014 "Imported Adyen Payments"
{
    PageType = List;
    Caption = 'Imported Adyen Payments';
    SourceTable = "Imported Adyen Payment";
    SourceTableView = sorting("Created At UTC", "Merchant Account", "PSP Reference") order(descending);
    UsageCategory = Lists;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Payments)
            {
                field("Created At UTC"; Rec."Created At UTC")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the imported payment record was created in Business Central.';
                }
                field("Merchant Account"; Rec."Merchant Account") { ApplicationArea = All; }
                field("PSP Reference"; Rec."PSP Reference")
                {
                    ApplicationArea = All;
                    DrillDown = true;
                    ToolTip = 'Specifies the original Adyen PSP reference. Drill down to view all lifecycle events for this merchant-qualified payment.';

                    trigger OnDrillDown()
                    begin
                        OpenLifecycleEvents();
                    end;
                }
                field("Merchant Reference"; Rec."Merchant Reference") { ApplicationArea = All; }
                field("Shopper Reference"; Rec."Shopper Reference") { ApplicationArea = All; }
                field("Resolved Customer No."; Rec."Resolved Customer No.") { ApplicationArea = All; }
                field("Payment Method"; Rec."Payment Method") { ApplicationArea = All; }
                field(Amount; Rec.Amount) { ApplicationArea = All; }
                field("Currency Code"; Rec."Currency Code") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("Adyen Lifecycle Status"; Rec."Adyen Lifecycle Status")
                {
                    ApplicationArea = All;
                    DrillDown = true;
                    ToolTip = 'Specifies the newest supported Adyen lifecycle state. Drill down to view the events and source records behind the lifecycle.';

                    trigger OnDrillDown()
                    begin
                        OpenLifecycleEvents();
                    end;
                }
                field("Posting Origin"; Rec."Posting Origin") { ApplicationArea = All; }
                field("Match Result"; Rec."Match Result") { ApplicationArea = All; }
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
                ToolTip = 'Run the safe matching rules again after correcting customer, policy, currency, amount, or invoice data. This action does not post the payment.';
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
                ToolTip = 'Post and apply the selected payment when it has exactly one safe invoice match and has not already been posted.';
                Enabled = (Rec.Status = Rec.Status::ReadyToPost) and
                          (Rec."Match Result" = Rec."Match Result"::UniqueExact) and
                          (Rec."Posted Payment Entry No." = 0);

                trigger OnAction()
                var
                    Poster: Codeunit "Adyen Payment Poster";
                begin
                    Poster.PostAndApplyManualExactMatch(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(CreateManualJournal)
            {
                Caption = 'Create Manual Journal Line';
                ApplicationArea = All;
                Image = Journal;
                ToolTip = 'Create one linked draft payment line in the merchant''s manual journal batch for finance review and posting.';
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
                ToolTip = 'Open the customer ledger entry created when the selected Adyen payment was posted.';
                Enabled = Rec."Posted Payment Entry No." <> 0;

                trigger OnAction()
                var
                    CustLedgerEntry: Record "Cust. Ledger Entry";
                begin
                    CustLedgerEntry.Get(Rec."Posted Payment Entry No.");
                    Page.Run(Page::"Customer Ledger Entries", CustLedgerEntry);
                end;
            }
            action(ViewLifecycleEvents)
            {
                Caption = 'View Lifecycle Events';
                ApplicationArea = All;
                Image = History;
                ToolTip = 'Open the chronological Adyen webhook and report events associated with this payment.';

                trigger OnAction()
                var
                    EventEntry: Record "Adyen Event Entry";
                begin
                    EventEntry.SetCurrentKey("Merchant Account", "Payment PSP Reference", "Occurred At UTC");
                    EventEntry.SetRange("Merchant Account", Rec."Merchant Account");
                    EventEntry.SetRange("Payment PSP Reference", Rec."PSP Reference");
                    Page.Run(Page::"Adyen Payment Lifecycle Events", EventEntry);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetCurrentKey("Created At UTC", "Merchant Account", "PSP Reference");
        Rec.Ascending(false);
    end;

    local procedure OpenLifecycleEvents()
    var
        EventEntry: Record "Adyen Event Entry";
    begin
        EventEntry.SetCurrentKey("Merchant Account", "Payment PSP Reference", "Occurred At UTC");
        EventEntry.SetRange("Merchant Account", Rec."Merchant Account");
        EventEntry.SetRange("Payment PSP Reference", Rec."PSP Reference");
        Page.Run(Page::"Adyen Payment Lifecycle Events", EventEntry);
    end;
}
