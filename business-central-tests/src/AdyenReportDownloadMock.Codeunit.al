codeunit 72153 "Adyen Report Download Mock"
{
    EventSubscriberInstance = Manual;

    var
        MockContent: Text;
        MockEnabled: Boolean;
        MockFailure: Boolean;

    procedure ConfigureSuccess(Content: Text)
    begin
        MockContent := Content;
        MockFailure := false;
        MockEnabled := true;
    end;

    procedure ConfigureFailure()
    begin
        MockFailure := true;
        MockEnabled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Adyen Report Downloader", 'OnBeforeDownloadContent', '', false, false)]
    local procedure SupplyReportContent(ReportRun: Record "Adyen Report Run"; var TempBlob: Codeunit "Temp Blob"; var IsHandled: Boolean)
    var
        ContentOutStream: OutStream;
    begin
        if not MockEnabled then
            exit;
        if MockFailure then
            Error('Simulated Adyen report HTTP failure.');
        TempBlob.CreateOutStream(ContentOutStream, TextEncoding::UTF8);
        ContentOutStream.WriteText(MockContent);
        IsHandled := true;
    end;
}
