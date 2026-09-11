codeunit 72049 "Adyen Report Worker"
{
    TableNo = "Adyen Report Run";

    trigger OnRun()
    var
        Downloader: Codeunit "Adyen Report Downloader";
        Parser: Codeunit "Adyen Report Parser";
    begin
        case Rec.Status of
            Rec.Status::Requested:
                begin
                    Downloader.Download(Rec);
                    Parser.PrepareRows(Rec);
                end;
            Rec.Status::Loading:
                Parser.LoadRows(Rec);
            else
                Error('Report run %1 cannot be processed from status %2.', Rec."Entry No.", Rec.Status);
        end;
    end;
}
