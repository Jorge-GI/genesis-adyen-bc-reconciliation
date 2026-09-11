page 72025 "Adyen Payment Lifecycle Events"
{
    PageType = List;
    Caption = 'Adyen Payment Lifecycle Events';
    SourceTable = "Adyen Event Entry";
    SourceTableView = sorting("Occurred At UTC", "Transport ID") order(descending);
    ApplicationArea = All;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Events)
            {
                field("Occurred At UTC"; Rec."Occurred At UTC") { ApplicationArea = All; }
                field("Message Type"; Rec."Message Type") { ApplicationArea = All; }
                field("Lifecycle Effect"; Rec."Lifecycle Effect") { ApplicationArea = All; }
                field("Previous Lifecycle Status"; Rec."Previous Lifecycle Status") { ApplicationArea = All; }
                field("Resulting Lifecycle Status"; Rec."Resulting Lifecycle Status") { ApplicationArea = All; }
                field(Source; Rec.Source) { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("Payment PSP Reference"; Rec."Payment PSP Reference") { ApplicationArea = All; }
                field("PSP Reference"; Rec."PSP Reference") { ApplicationArea = All; }
                field("Original PSP Reference"; Rec."Original PSP Reference") { ApplicationArea = All; }
                field("Webhook Request Entry No."; Rec."Webhook Request Entry No.") { ApplicationArea = All; }
                field("Report Run Entry No."; Rec."Report Run Entry No.") { ApplicationArea = All; }
                field("Report Row No."; Rec."Report Row No.") { ApplicationArea = All; }
                field("Success Provided"; Rec."Success Provided") { ApplicationArea = All; }
                field(Success; Rec.Success) { ApplicationArea = All; }
                field("Adyen Reason"; Rec.Reason)
                {
                    ApplicationArea = All;
                    Caption = 'Adyen Reason';
                }
                field("Disposition Reason"; Rec."Disposition Reason") { ApplicationArea = All; }
                field("Received At UTC"; Rec."Received At UTC") { ApplicationArea = All; }
                field("Processed At UTC"; Rec."Processed At UTC") { ApplicationArea = All; }
                field("Last Error"; Rec."Last Error") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenSource)
            {
                Caption = 'Open Source';
                ApplicationArea = All;
                Image = ViewDetails;
                ToolTip = 'Open the webhook request or report run from which the selected event originated.';

                trigger OnAction()
                var
                    ReportRun: Record "Adyen Report Run";
                    WebhookRequest: Record "Adyen Webhook Request";
                begin
                    case Rec.Source of
                        Rec.Source::Webhook:
                            begin
                                Rec.TestField("Webhook Request Entry No.");
                                if not WebhookRequest.Get(Rec."Webhook Request Entry No.") then
                                    Error('Webhook request %1 no longer exists.', Rec."Webhook Request Entry No.");
                                WebhookRequest.SetRecFilter();
                                Page.Run(Page::"Adyen Webhook Requests", WebhookRequest);
                            end;
                        Rec.Source::Report:
                            begin
                                Rec.TestField("Report Run Entry No.");
                                if not ReportRun.Get(Rec."Report Run Entry No.") then
                                    Error('Report run %1 no longer exists.', Rec."Report Run Entry No.");
                                ReportRun.SetRecFilter();
                                Page.Run(Page::"Adyen Report Runs", ReportRun);
                            end;
                    end;
                end;
            }
        }
    }
}
