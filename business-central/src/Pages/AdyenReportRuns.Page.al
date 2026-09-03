page 72013 "Adyen Report Runs"
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
                field("External Report ID"; Rec."External Report ID") { ApplicationArea = All; }
                field("Report Date"; Rec."Report Date") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("Total Row Count"; Rec."Total Row Count") { ApplicationArea = All; }
                field("Relevant Row Count"; Rec."Relevant Row Count") { ApplicationArea = All; }
                field("Loaded Row Count"; Rec."Loaded Row Count") { ApplicationArea = All; }
                field("Ready At UTC"; Rec."Ready At UTC") { ApplicationArea = All; }
                field("Error Message"; Rec."Error Message") { ApplicationArea = All; }
                field("Archive Reference"; Rec."Archive Reference") { ApplicationArea = All; }
            }
        }
    }
}
