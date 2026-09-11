page 72015 "Adyen Payment Exceptions"
{
    PageType = List;
    Caption = 'Adyen Payment Exceptions';
    SourceTable = "Imported Adyen Payment";
    SourceTableView = sorting("Created At UTC", "Merchant Account", "PSP Reference") order(descending) where(Status = filter(Imported | Error | ReversalRequired | DataConflict));
    UsageCategory = Lists;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Exceptions)
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
                field("Shopper Reference"; Rec."Shopper Reference") { ApplicationArea = All; }
                field("Resolved Customer No."; Rec."Resolved Customer No.") { ApplicationArea = All; }
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
                field("Match Result"; Rec."Match Result") { ApplicationArea = All; }
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
                ToolTip = 'Create one linked draft payment line in the merchant''s manual journal batch for an imported or errored payment.';
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
