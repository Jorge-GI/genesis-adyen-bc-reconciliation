page 72016 "Adyen Report Runs"
{
    PageType = List;
    Caption = 'Adyen Report Runs';
    SourceTable = "Adyen Report Run";
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
                field("External Report ID"; Rec."External Report ID") { ApplicationArea = All; }
                field("Report Date"; Rec."Report Date") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("File Hash"; Rec."File Hash") { ApplicationArea = All; }
                field("Total Row Count"; Rec."Total Row Count") { ApplicationArea = All; }
                field("Relevant Row Count"; Rec."Relevant Row Count") { ApplicationArea = All; }
                field("Loaded Row Count"; Rec."Loaded Row Count") { ApplicationArea = All; }
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
            action(Retry)
            {
                Caption = 'Retry';
                ApplicationArea = All;
                Image = Refresh;
                Enabled = Rec.Status = Rec.Status::Error;

                trigger OnAction()
                begin
                    Rec.TestField("Content Purged", false);
                    Rec.Status := Rec.Status::Requested;
                    Rec."Last Error" := '';
                    Rec.Modify(true);
                    CurrPage.Update(false);
                end;
            }
            action(DownloadReport)
            {
                Caption = 'Download Report';
                ApplicationArea = All;
                Image = ExportFile;

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
}
