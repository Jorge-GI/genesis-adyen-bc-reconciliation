page 72023 "Adyen Role Center Actions"
{
    PageType = CardPart;
    Caption = 'Adyen Quick Access';
    SourceTable = "Adyen Role Center Cue";
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            cuegroup(Reconcile)
            {
                Caption = 'Reconcile';

                actions
                {
                    action(PaymentExceptions)
                    {
                        ApplicationArea = All;
                        Caption = 'Payment Exceptions';
                        RunObject = Page "Adyen Payment Exceptions";
                        RunPageView = sorting("Created At UTC", "Merchant Account", "PSP Reference") order(descending);
                        ToolTip = 'Review Adyen payments that are unmatched, errored, require reversal, or contain conflicting data.';
                    }
                    action(ImportedPayments)
                    {
                        ApplicationArea = All;
                        Caption = 'Imported Adyen Payments';
                        ToolTip = 'View imported Adyen payments, their matching results, report state, and posting outcome.';

                        trigger OnAction()
                        var
                            Payment: Record "Imported Adyen Payment";
                        begin
                            OpenImportedPayments(Payment);
                        end;
                    }
                    action(PostedPayments)
                    {
                        ApplicationArea = All;
                        Caption = 'Posted Adyen Payments';
                        RunObject = Page "Posted Adyen Payments";
                        ToolTip = 'Review Adyen payments that have a linked posted customer ledger entry and open all related posting entries.';
                    }
                    action(PaymentJournal)
                    {
                        AccessByPermission = tabledata "Gen. Journal Line" = RIMD;
                        ApplicationArea = Basic, Suite;
                        Caption = 'Payment Journal';
                        RunObject = Page "Payment Journal";
                        ToolTip = 'Open payment journals to review and post manual Adyen payment lines.';
                    }
                }
            }
            cuegroup(Monitor)
            {
                Caption = 'Monitor';

                actions
                {
                    action(WebhookRequests)
                    {
                        AccessByPermission = tabledata "Adyen Webhook Request" = R;
                        ApplicationArea = All;
                        Caption = 'Webhook Requests';
                        RunObject = Page "Adyen Webhook Requests";
                        ToolTip = 'Monitor accepted webhook envelopes, normalization status, retries, and retained payloads.';
                    }
                    action(EventEntries)
                    {
                        AccessByPermission = tabledata "Adyen Event Entry" = R;
                        ApplicationArea = All;
                        Caption = 'Event Entries';
                        RunObject = Page "Adyen Event Entries";
                        ToolTip = 'Monitor normalized webhook and report events, processing decisions, and errors.';
                    }
                    action(ReportRuns)
                    {
                        AccessByPermission = tabledata "Adyen Report Run" = R;
                        ApplicationArea = All;
                        Caption = 'Report Runs';
                        RunObject = Page "Adyen Report Runs";
                        ToolTip = 'Monitor Adyen report downloads, loading, reconciliation, row counts, and errors.';
                    }
                }
            }
            cuegroup(Configure)
            {
                Caption = 'Configure';

                actions
                {
                    action(Setup)
                    {
                        AccessByPermission = tabledata "Adyen Setup" = M;
                        ApplicationArea = All;
                        Caption = 'Adyen Setup';
                        RunObject = Page "Adyen Setup";
                        ToolTip = 'Configure the integration environment, credentials, processing limits, report access, retention, and background queue.';
                    }
                    action(Merchants)
                    {
                        AccessByPermission = tabledata "Adyen Merchant" = I;
                        ApplicationArea = All;
                        Caption = 'Merchants';
                        RunObject = Page "Adyen Merchants";
                        ToolTip = 'Configure Adyen merchant accounts, posting journals, clearing accounts, and automatic posting.';
                    }
                    action(PaymentMethodPolicies)
                    {
                        AccessByPermission = tabledata "Adyen Merchant Method Policy" = I;
                        ApplicationArea = All;
                        Caption = 'Payment Method Policies';
                        RunObject = Page "Adyen Payment Method Policies";
                        ToolTip = 'Configure which payment methods are eligible for automatic matching and posting for each merchant.';
                    }
                    action(AdyenJobQueue)
                    {
                        AccessByPermission = tabledata "Job Queue Entry" = R;
                        ApplicationArea = Suite;
                        Caption = 'Adyen Job Queue';
                        RunObject = Page "Job Queue Entries";
                        RunPageView = where("Object Type to Run" = const(Codeunit), "Object ID to Run" = const(72044));
                        ToolTip = 'View the background Job Queue entry that runs the Adyen dispatcher.';
                    }
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec.Insert();
        end;
    end;

    local procedure OpenImportedPayments(var Payment: Record "Imported Adyen Payment")
    begin
        Payment.SetCurrentKey("Created At UTC", "Merchant Account", "PSP Reference");
        Payment.Ascending(false);
        Page.Run(Page::"Imported Adyen Payments", Payment);
    end;
}
