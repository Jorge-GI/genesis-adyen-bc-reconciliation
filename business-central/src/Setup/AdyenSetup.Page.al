page 72010 "Adyen Setup"
{
    PageType = Card;
    Caption = 'Adyen Setup';
    SourceTable = "Adyen Setup";
    UsageCategory = Administration;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field(Enabled; Rec.Enabled) { ApplicationArea = All; }
                field("Merchant Account"; Rec."Merchant Account") { ApplicationArea = All; }
                field(Environment; Rec.Environment) { ApplicationArea = All; }
                field("Auto Post"; Rec."Auto Post") { ApplicationArea = All; }
            }
            group(Posting)
            {
                Caption = 'Posting';
                field("Journal Template Name"; Rec."Journal Template Name") { ApplicationArea = All; }
                field("Journal Batch Name"; Rec."Journal Batch Name") { ApplicationArea = All; }
                field("Manual Journal Batch Name"; Rec."Manual Journal Batch Name") { ApplicationArea = All; }
                field("Clearing G/L Account No."; Rec."Clearing G/L Account No.") { ApplicationArea = All; }
            }
            group(Reports)
            {
                Caption = 'Reports';
                field("Report Deadline"; Rec."Report Deadline") { ApplicationArea = All; }
                field("Last Ready Report Date"; Rec."Last Ready Report Date") { ApplicationArea = All; }
                field("Raw Retention Days"; Rec."Raw Retention Days") { ApplicationArea = All; }
                field("Report Retention Months"; Rec."Report Retention Months") { ApplicationArea = All; }
                field("Report Overdue"; Rec."Report Overdue") { ApplicationArea = All; }
                field("Report Alert Message"; Rec."Report Alert Message") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CreateJobQueueEntry)
            {
                Caption = 'Create Job Queue Entry';
                ApplicationArea = All;
                Image = Job;

                trigger OnAction()
                var
                    JobQueueSetup: Codeunit "Adyen Job Queue Setup";
                begin
                    JobQueueSetup.EnsureEntry();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.GetRecordOnce();
    end;
}
