page 72016 "Adyen Report Runs"
{
    PageType = List;
    Caption = 'Adyen Report Runs';
    SourceTable = "Adyen Report Run";
    SourceTableView = sorting("Requested At UTC", "Entry No.") order(descending);
    UsageCategory = History;
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Runs)
            {
                field("Merchant Account"; Rec."Merchant Account") { ApplicationArea = All; }
                field("External Report ID"; Rec."External Report ID")
                {
                    ApplicationArea = All;
                    DrillDown = true;

                    trigger OnDrillDown()
                    begin
                        OpenImportedEvents();
                    end;
                }
                field("Report Date"; Rec."Report Date") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("File Hash"; Rec."File Hash") { ApplicationArea = All; }
                field("Total Row Count"; Rec."Total Row Count") { ApplicationArea = All; }
                field("Relevant Row Count"; Rec."Relevant Row Count") { ApplicationArea = All; }
                field("Loaded Row Count"; Rec."Loaded Row Count")
                {
                    ApplicationArea = All;
                    DrillDown = true;

                    trigger OnDrillDown()
                    begin
                        OpenImportedEvents();
                    end;
                }
                field("Retry Count"; Rec."Retry Count") { ApplicationArea = All; }
                field("Last Error"; Rec."Last Error") { ApplicationArea = All; }
                field("Ready At UTC"; Rec."Ready At UTC") { ApplicationArea = All; }
                field("Content Purged"; Rec."Content Purged") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ImportedEvents)
            {
                Caption = 'Imported Events';
                ApplicationArea = All;
                Image = Entries;
                ToolTip = 'Open the events imported from the selected report run.';

                trigger OnAction()
                begin
                    OpenImportedEvents();
                end;
            }
            action(Retry)
            {
                Caption = 'Retry';
                ApplicationArea = All;
                Image = Refresh;
                ToolTip = 'Queue the selected errored report for another background download, load, and reconciliation attempt.';
                Enabled = Rec.Status = Rec.Status::Error;

                trigger OnAction()
                var
                    ReportManagement: Codeunit "Adyen Report Management";
                begin
                    ReportManagement.Retry(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(DownloadReport)
            {
                Caption = 'Download Report';
                ApplicationArea = All;
                Image = ExportFile;
                ToolTip = 'Download the retained original report as a CSV file. This is unavailable after retention cleanup purges the content.';

                trigger OnAction()
                var
                    ReportInStream: InStream;
                    FileName: Text;
                begin
                    Rec.CalcFields(Content);
                    if not Rec.Content.HasValue() then
                        Error('The report content is not retained.');
                    Rec.Content.CreateInStream(ReportInStream);
                    FileName := Rec."External Report ID";
                    DownloadFromStream(ReportInStream, '', '', 'CSV (*.csv)|*.csv', FileName);
                end;
            }
        }
    }

    local procedure OpenImportedEvents()
    var
        EventEntry: Record "Adyen Event Entry";
    begin
        EventEntry.SetRange("Report Run Entry No.", Rec."Entry No.");
        Page.Run(Page::"Adyen Event Entries", EventEntry);
    end;
}
