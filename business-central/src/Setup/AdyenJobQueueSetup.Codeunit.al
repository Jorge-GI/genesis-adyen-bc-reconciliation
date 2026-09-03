codeunit 72036 "Adyen Job Queue Setup"
{
    procedure EnsureEntry()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"Adyen Inbox Dispatcher");
        if JobQueueEntry.FindFirst() then begin
            Page.Run(Page::"Job Queue Entry Card", JobQueueEntry);
            exit;
        end;

        JobQueueEntry.Init();
        JobQueueEntry.ID := CreateGuid();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"Adyen Inbox Dispatcher";
        JobQueueEntry.Description := 'Process Adyen payment and report inbox';
        JobQueueEntry."Recurring Job" := true;
        JobQueueEntry."No. of Minutes between Runs" := 1;
        JobQueueEntry.Status := JobQueueEntry.Status::"On Hold";
        JobQueueEntry.Insert(true);
        Page.Run(Page::"Job Queue Entry Card", JobQueueEntry);
    end;
}
