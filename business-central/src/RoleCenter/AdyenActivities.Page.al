page 72021 "Adyen Activities"
{
    PageType = CardPart;
    Caption = 'Adyen Activities';
    SourceTable = "Adyen Role Center Cue";
    ApplicationArea = All;
    Editable = false;
    RefreshOnActivate = true;

    layout
    {
        area(Content)
        {
            cuegroup(Reconciliation)
            {
                Caption = 'Reconciliation';

                field("Payment Exceptions"; Rec."Payment Exceptions")
                {
                    ApplicationArea = All;
                    StyleExpr = PaymentExceptionsStyle;
                    ToolTip = 'Specifies the number of imported payments that require finance review because they are unmatched, errored, require reversal, or contain conflicting data.';

                    trigger OnDrillDown()
                    var
                        Payment: Record "Imported Adyen Payment";
                    begin
                        Payment.SetFilter(Status, '%1|%2|%3|%4', Payment.Status::Imported, Payment.Status::Error,
                          Payment.Status::ReversalRequired, Payment.Status::DataConflict);
                        Payment.SetCurrentKey("Created At UTC", "Merchant Account", "PSP Reference");
                        Payment.Ascending(false);
                        Page.Run(Page::"Adyen Payment Exceptions", Payment);
                    end;
                }
                field("Ready to Post"; Rec."Ready to Post")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of imported Adyen payments that passed matching checks and are ready to be posted and applied.';

                    trigger OnDrillDown()
                    var
                        Payment: Record "Imported Adyen Payment";
                    begin
                        Payment.SetRange(Status, Payment.Status::ReadyToPost);
                        OpenImportedPayments(Payment);
                    end;
                }
                field("Manual Journal Drafts"; Rec."Manual Journal Drafts")
                {
                    ApplicationArea = All;
                    StyleExpr = ManualJournalDraftsStyle;
                    ToolTip = 'Specifies the number of imported Adyen payments that have a linked manual payment-journal draft awaiting review or posting.';

                    trigger OnDrillDown()
                    var
                        Payment: Record "Imported Adyen Payment";
                    begin
                        Payment.SetRange(Status, Payment.Status::ManualJournalCreated);
                        OpenImportedPayments(Payment);
                    end;
                }
            }
            cuegroup(PaymentStatistics)
            {
                Caption = 'Payment Statistics';

                field("Total Imported Payments"; Rec."Total Imported Payments")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the total number of Adyen payments imported into this company.';

                    trigger OnDrillDown()
                    var
                        Payment: Record "Imported Adyen Payment";
                    begin
                        OpenImportedPayments(Payment);
                    end;
                }
                field("Posted Adyen Payments"; Rec."Posted Adyen Payments")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of Adyen payments that have a linked posted customer ledger entry.';

                    trigger OnDrillDown()
                    begin
                        Page.Run(Page::"Posted Adyen Payments");
                    end;
                }

                field("Automatically Posted"; Rec."Automatically Posted")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of posted Adyen payments that the extension posted automatically after finding a unique exact match.';

                    trigger OnDrillDown()
                    var
                        Payment: Record "Imported Adyen Payment";
                    begin
                        Payment.SetFilter("Posted Payment Entry No.", '<>0');
                        Payment.SetRange("Posting Origin", Payment."Posting Origin"::Automatic);
                        Page.Run(Page::"Posted Adyen Payments", Payment);
                    end;
                }
                field("Manually Posted"; Rec."Manually Posted")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of posted Adyen payments posted by a user through Post Exact Match or a reviewed manual journal.';

                    trigger OnDrillDown()
                    var
                        Payment: Record "Imported Adyen Payment";
                    begin
                        Payment.SetFilter("Posted Payment Entry No.", '<>0');
                        Payment.SetFilter("Posting Origin", '%1|%2', Payment."Posting Origin"::ManualExactMatch,
                          Payment."Posting Origin"::ManualJournal);
                        Page.Run(Page::"Posted Adyen Payments", Payment);
                    end;
                }
                field("Unclassified Posted"; Rec."Unclassified Posted")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of posted Adyen payments for which no posting route has been recorded.';

                    trigger OnDrillDown()
                    var
                        Payment: Record "Imported Adyen Payment";
                    begin
                        Payment.SetFilter("Posted Payment Entry No.", '<>0');
                        Payment.SetRange("Posting Origin", Payment."Posting Origin"::Unclassified);
                        Page.Run(Page::"Posted Adyen Payments", Payment);
                    end;
                }
            }
            cuegroup(Processing)
            {
                Caption = 'Processing';

                field("Pending Webhook Requests"; Rec."Pending Webhook Requests")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of accepted webhook requests that are waiting for normalization or are currently being processed.';

                    trigger OnDrillDown()
                    var
                        WebhookRequest: Record "Adyen Webhook Request";
                    begin
                        WebhookRequest.SetFilter(Status, '%1|%2', WebhookRequest.Status::Received, WebhookRequest.Status::Processing);
                        Page.Run(Page::"Adyen Webhook Requests", WebhookRequest);
                    end;
                }

                field("Webhook Errors"; Rec."Webhook Errors")
                {
                    ApplicationArea = All;
                    StyleExpr = WebhookErrorsStyle;
                    ToolTip = 'Specifies the number of webhook requests that could not be normalized and can be reviewed for retry.';

                    trigger OnDrillDown()
                    var
                        WebhookRequest: Record "Adyen Webhook Request";
                    begin
                        WebhookRequest.SetRange(Status, WebhookRequest.Status::Error);
                        Page.Run(Page::"Adyen Webhook Requests", WebhookRequest);
                    end;
                }
                field("Pending Event Entries"; Rec."Pending Event Entries")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of normalized Adyen events that are waiting for lifecycle, matching, or reconciliation processing.';

                    trigger OnDrillDown()
                    var
                        EventEntry: Record "Adyen Event Entry";
                    begin
                        EventEntry.SetFilter(Status, '%1|%2', EventEntry.Status::Received, EventEntry.Status::Processing);
                        Page.Run(Page::"Adyen Event Entries", EventEntry);
                    end;
                }
                field("Event Errors"; Rec."Event Errors")
                {
                    ApplicationArea = All;
                    StyleExpr = EventErrorsStyle;
                    ToolTip = 'Specifies the number of normalized Adyen events that failed during lifecycle, matching, or reconciliation processing.';

                    trigger OnDrillDown()
                    var
                        EventEntry: Record "Adyen Event Entry";
                    begin
                        EventEntry.SetRange(Status, EventEntry.Status::Error);
                        Page.Run(Page::"Adyen Event Entries", EventEntry);
                    end;
                }
                field("Active Report Runs"; Rec."Active Report Runs")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of Adyen report runs that are requested, downloading, loading, ready, or being reconciled.';

                    trigger OnDrillDown()
                    var
                        ReportRun: Record "Adyen Report Run";
                    begin
                        ReportRun.SetFilter(Status, '%1|%2|%3|%4|%5', ReportRun.Status::Requested,
                          ReportRun.Status::Downloading, ReportRun.Status::Loading, ReportRun.Status::Ready,
                          ReportRun.Status::Processing);
                        Page.Run(Page::"Adyen Report Runs", ReportRun);
                    end;
                }
                field("Report Errors"; Rec."Report Errors")
                {
                    ApplicationArea = All;
                    StyleExpr = ReportErrorsStyle;
                    ToolTip = 'Specifies the number of Adyen report runs that failed during download, loading, or reconciliation.';

                    trigger OnDrillDown()
                    var
                        ReportRun: Record "Adyen Report Run";
                    begin
                        ReportRun.SetRange(Status, ReportRun.Status::Error);
                        Page.Run(Page::"Adyen Report Runs", ReportRun);
                    end;
                }
            }
            cuegroup(Merchants)
            {
                Caption = 'Merchants';

                field("Overdue Merchants"; Rec."Overdue Merchants")
                {
                    ApplicationArea = All;
                    StyleExpr = OverdueMerchantsStyle;
                    ToolTip = 'Specifies the number of enabled Adyen merchants whose expected daily accounting report is overdue.';

                    trigger OnDrillDown()
                    var
                        Merchant: Record "Adyen Merchant";
                    begin
                        Merchant.SetRange(Enabled, true);
                        Merchant.SetRange("Report Overdue", true);
                        Page.Run(Page::"Adyen Merchants", Merchant);
                    end;
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

    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields("Payment Exceptions", "Ready to Post", "Total Imported Payments", "Posted Adyen Payments", "Automatically Posted",
          "Manually Posted", "Unclassified Posted", "Manual Journal Drafts",
          "Pending Webhook Requests", "Webhook Errors", "Pending Event Entries", "Event Errors",
          "Active Report Runs", "Report Errors", "Overdue Merchants");
        SetCueStyles();
    end;

    var
        EventErrorsStyle: Text;
        ManualJournalDraftsStyle: Text;
        OverdueMerchantsStyle: Text;
        PaymentExceptionsStyle: Text;
        ReportErrorsStyle: Text;
        WebhookErrorsStyle: Text;

    local procedure SetCueStyles()
    begin
        Clear(PaymentExceptionsStyle);
        Clear(ManualJournalDraftsStyle);
        Clear(WebhookErrorsStyle);
        Clear(EventErrorsStyle);
        Clear(ReportErrorsStyle);
        Clear(OverdueMerchantsStyle);

        if Rec."Payment Exceptions" > 0 then
            PaymentExceptionsStyle := 'Attention';
        if Rec."Manual Journal Drafts" > 0 then
            ManualJournalDraftsStyle := 'Attention';
        if Rec."Webhook Errors" > 0 then
            WebhookErrorsStyle := 'Unfavorable';
        if Rec."Event Errors" > 0 then
            EventErrorsStyle := 'Unfavorable';
        if Rec."Report Errors" > 0 then
            ReportErrorsStyle := 'Unfavorable';
        if Rec."Overdue Merchants" > 0 then
            OverdueMerchantsStyle := 'Attention';
    end;

    local procedure OpenImportedPayments(var Payment: Record "Imported Adyen Payment")
    begin
        Payment.SetCurrentKey("Created At UTC", "Merchant Account", "PSP Reference");
        Payment.Ascending(false);
        Page.Run(Page::"Imported Adyen Payments", Payment);
    end;
}
