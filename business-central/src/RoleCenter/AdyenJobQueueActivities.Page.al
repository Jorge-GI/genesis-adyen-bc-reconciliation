page 72026 "Adyen Job Queue Activities"
{
    PageType = CardPart;
    Caption = 'Adyen Job Queue Tasks';
    SourceTable = "Adyen Role Center Cue";
    ApplicationArea = Suite;
    Editable = false;
    RefreshOnActivate = true;

    layout
    {
        area(Content)
        {
            cuegroup(AdyenJobQueue)
            {
                Caption = 'Adyen Job Queue Tasks';

                field("Adyen Tasks Failed"; Rec."Adyen Tasks Failed")
                {
                    ApplicationArea = Suite;
                    StyleExpr = FailedTasksStyle;
                    ToolTip = 'Specifies the number of Adyen dispatcher Job Queue entries that failed.';

                    trigger OnDrillDown()
                    var
                        JobQueueEntry: Record "Job Queue Entry";
                    begin
                        SetAdyenDispatcherFilter(JobQueueEntry);
                        JobQueueEntry.SetRange(Status, JobQueueEntry.Status::Error);
                        Page.Run(Page::"Job Queue Entries", JobQueueEntry);
                    end;
                }
                field("Adyen Tasks In Process"; Rec."Adyen Tasks In Process")
                {
                    ApplicationArea = Suite;
                    ToolTip = 'Specifies the number of Adyen dispatcher Job Queue entries that are currently processing.';

                    trigger OnDrillDown()
                    var
                        JobQueueEntry: Record "Job Queue Entry";
                    begin
                        SetAdyenDispatcherFilter(JobQueueEntry);
                        JobQueueEntry.SetRange(Status, JobQueueEntry.Status::"In Process");
                        Page.Run(Page::"Job Queue Entries", JobQueueEntry);
                    end;
                }
                field("Adyen Tasks In Queue"; Rec."Adyen Tasks In Queue")
                {
                    ApplicationArea = Suite;
                    ToolTip = 'Specifies the number of Adyen dispatcher Job Queue entries that are ready or waiting to run.';

                    trigger OnDrillDown()
                    var
                        JobQueueEntry: Record "Job Queue Entry";
                    begin
                        SetAdyenDispatcherFilter(JobQueueEntry);
                        JobQueueEntry.SetFilter(Status, '%1|%2', JobQueueEntry.Status::Ready, JobQueueEntry.Status::Waiting);
                        Page.Run(Page::"Job Queue Entries", JobQueueEntry);
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
        Rec.CalcFields("Adyen Tasks Failed", "Adyen Tasks In Process", "Adyen Tasks In Queue");
        Clear(FailedTasksStyle);
        if Rec."Adyen Tasks Failed" > 0 then
            FailedTasksStyle := 'Unfavorable';
    end;

    var
        FailedTasksStyle: Text;

    local procedure SetAdyenDispatcherFilter(var JobQueueEntry: Record "Job Queue Entry")
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"Adyen Dispatcher");
    end;
}
