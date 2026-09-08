codeunit 72049 "Adyen Report Worker"
{
    TableNo = "Adyen Report Run";

    trigger OnRun()
    var
        Downloader: Codeunit "Adyen Report Downloader";
        Parser: Codeunit "Adyen Report Parser";
    begin
        Downloader.Download(Rec);
        Parser.LoadRows(Rec);
    end;
}
