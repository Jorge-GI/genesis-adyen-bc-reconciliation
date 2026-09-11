page 72012 "Adyen Webhook Requests"
{
    PageType = List;
    Caption = 'Adyen Webhook Requests';
    SourceTable = "Adyen Webhook Request";
    SourceTableView = sorting("Received At UTC", "Entry No.") order(descending);
    UsageCategory = History;
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Requests)
            {
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; }
                field("Received At UTC"; Rec."Received At UTC") { ApplicationArea = All; }
                field("Flow Run ID"; Rec."Flow Run ID") { ApplicationArea = All; }
                field("Payload Hash"; Rec."Payload Hash") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; }
                field("Item Count"; Rec."Item Count") { ApplicationArea = All; }
                field("Normalized Item Count"; Rec."Normalized Item Count") { ApplicationArea = All; }
                field("Retry Count"; Rec."Retry Count") { ApplicationArea = All; }
                field("Last Error"; Rec."Last Error") { ApplicationArea = All; }
                field("Raw Content Purged"; Rec."Raw Content Purged") { ApplicationArea = All; }
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
                ToolTip = 'Return the selected errored webhook request to the queue so its retained payload can be normalized again.';
                Enabled = Rec.Status = Rec.Status::Error;

                trigger OnAction()
                begin
                    Rec.TestField("Raw Content Purged", false);
                    Rec.Status := Rec.Status::Received;
                    Rec."Last Error" := '';
                    Rec.Modify(true);
                    CurrPage.Update(false);
                end;
            }
            action(DownloadPayload)
            {
                Caption = 'Download Payload';
                ApplicationArea = All;
                Image = ExportFile;
                ToolTip = 'Download the retained raw webhook envelope as a JSON file. This is unavailable after retention cleanup purges the payload.';

                trigger OnAction()
                var
                    PayloadInStream: InStream;
                    FileName: Text;
                begin
                    Rec.CalcFields(Payload);
                    if not Rec.Payload.HasValue() then
                        Error('The raw webhook payload is not retained.');
                    Rec.Payload.CreateInStream(PayloadInStream);
                    FileName := StrSubstNo('adyen-webhook-%1.json', Rec."Entry No.");
                    DownloadFromStream(PayloadInStream, '', '', 'JSON (*.json)|*.json', FileName);
                end;
            }
        }
    }
}
