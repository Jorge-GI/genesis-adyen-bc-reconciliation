page 72024 "Posted Adyen Payments"
{
    PageType = List;
    Caption = 'Posted Adyen Payments';
    SourceTable = "Imported Adyen Payment";
    SourceTableView = sorting("Posted Payment Entry No.", "Posting Origin") order(descending) where("Posted Payment Entry No." = filter(<> 0));
    UsageCategory = History;
    ApplicationArea = All;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Payments)
            {
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
                field(PostedBy; PostedByUserId)
                {
                    ApplicationArea = All;
                    Caption = 'Posted By';
                    ToolTip = 'Specifies the user who posted the linked customer ledger entry. This value comes from the customer ledger entry and is not stored on the Adyen payment.';
                }
                field(PostedAt; PostedAtDateTime)
                {
                    ApplicationArea = All;
                    Caption = 'Posted At';
                    ToolTip = 'Specifies when the linked customer ledger entry was created. This value comes from the customer ledger entry and is not stored on the Adyen payment.';
                }
                field("Posted Payment Entry No."; Rec."Posted Payment Entry No.") { ApplicationArea = All; }
                field("Event Date-Time"; Rec."Event Date-Time") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenPostedPayment)
            {
                AccessByPermission = tabledata "Cust. Ledger Entry" = R;
                ApplicationArea = Basic, Suite;
                Caption = 'Open Posted Payment';
                Image = CustomerLedger;
                ToolTip = 'Open the customer ledger entry created when the selected Adyen payment was posted.';

                trigger OnAction()
                var
                    CustLedgerEntry: Record "Cust. Ledger Entry";
                begin
                    CustLedgerEntry.Get(Rec."Posted Payment Entry No.");
                    Page.Run(Page::"Customer Ledger Entries", CustLedgerEntry);
                end;
            }
            action(FindRelatedEntries)
            {
                AccessByPermission = tabledata "G/L Entry" = R;
                ApplicationArea = Basic, Suite;
                Caption = 'Find Related Entries';
                Image = Navigate;
                ToolTip = 'Show all posted documents and ledger entries that share the posted Adyen payment document number and posting date.';

                trigger OnAction()
                var
                    CustLedgerEntry: Record "Cust. Ledger Entry";
                    Navigate: Page Navigate;
                begin
                    CustLedgerEntry.Get(Rec."Posted Payment Entry No.");
                    Navigate.SetDoc(CustLedgerEntry."Posting Date", CustLedgerEntry."Document No.");
                    Navigate.Run();
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
    begin
        Clear(PostedByUserId);
        Clear(PostedAtDateTime);
        if CustLedgerEntry.Get(Rec."Posted Payment Entry No.") then begin
            PostedByUserId := CustLedgerEntry."User ID";
            PostedAtDateTime := CustLedgerEntry.SystemCreatedAt;
        end;
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

    var
        PostedAtDateTime: DateTime;
        PostedByUserId: Code[50];
}
