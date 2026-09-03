page 72021 "Adyen Report Runs API"
{
    PageType = API;
    APIPublisher = 'genesisimport';
    APIGroup = 'adyen';
    APIVersion = 'v1.0';
    EntityName = 'adyenReportRun';
    EntitySetName = 'adyenReportRuns';
    EntityCaption = 'Adyen Report Run';
    EntitySetCaption = 'Adyen Report Runs';
    SourceTable = "Adyen Report Run";
    ODataKeyFields = "External Report ID";
    DelayedInsert = true;
    InsertAllowed = true;
    ModifyAllowed = true;
    DeleteAllowed = false;
    Extensible = false;

    layout
    {
        area(Content)
        {
            repeater(Runs)
            {
                field(externalReportId; Rec."External Report ID") { Caption = 'External Report ID'; }
                field(fileHash; Rec."File Hash") { Caption = 'File Hash'; }
                field(reportDate; Rec."Report Date") { Caption = 'Report Date'; }
                field(state; Rec.Status) { Caption = 'State'; }
                field(totalRowCount; Rec."Total Row Count") { Caption = 'Total Row Count'; }
                field(relevantRowCount; Rec."Relevant Row Count") { Caption = 'Relevant Row Count'; }
                field(loadedRowCount; Rec."Loaded Row Count") { Caption = 'Loaded Row Count'; }
                field(archiveReference; Rec."Archive Reference") { Caption = 'Archive Reference'; }
                field(errorMessage; Rec."Error Message") { Caption = 'Error Message'; }
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        ExistingRun: Record "Adyen Report Run";
    begin
        if ExistingRun.Get(Rec."External Report ID") then begin
            if ExistingRun."File Hash" <> Rec."File Hash" then
                Error('Report %1 already exists with a different file hash.', Rec."External Report ID");
            Rec := ExistingRun;
            exit(false);
        end;

        Rec.Insert(true);
        exit(false);
    end;

    trigger OnModifyRecord(): Boolean
    var
        Setup: Record "Adyen Setup";
    begin
        if Rec.Status = Rec.Status::Ready then begin
            if Rec."Relevant Row Count" <> Rec."Loaded Row Count" then
                Error('A report cannot be made ready until all relevant rows are loaded.');
            Rec."Ready At UTC" := CurrentDateTime();
            Rec."Error Message" := '';
            Setup.GetRecordOnce();
            if Rec."Report Date" > Setup."Last Ready Report Date" then begin
                Setup."Last Ready Report Date" := Rec."Report Date";
                Setup.Modify(true);
            end;
        end;

        Rec.Modify(true);
        exit(false);
    end;
}
