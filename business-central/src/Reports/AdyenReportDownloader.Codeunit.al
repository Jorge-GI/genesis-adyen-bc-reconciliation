codeunit 72040 "Adyen Report Downloader"
{
    [NonDebuggable]
    procedure Download(var ReportRun: Record "Adyen Report Run")
    var
        Setup: Record "Adyen Setup";
        Credentials: Codeunit "Adyen Credentials";
        Crypto: Codeunit "Adyen Cryptography";
        TempBlob: Codeunit "Temp Blob";
        HashInStream: InStream;
        CopyInStream: InStream;
        ReportOutStream: OutStream;
        UserName: SecretText;
        Password: SecretText;
        IsHandled: Boolean;
    begin
        if GuiAllowed() then
            Error('Adyen report downloads can run only in a background session.');
        Setup.GetRecordOnce();
        Setup.ValidateForReportDownload();
        ValidateDownloadUrl(ReportRun."Download URL", Setup."Allowed Report Hosts");
        if not Credentials.GetReportUser(UserName) or not Credentials.GetReportPassword(Password) then
            Error('The Adyen report credentials are not configured.');

        ReportRun.Status := ReportRun.Status::Downloading;
        ReportRun."Last Error" := '';
        ReportRun.Modify(true);

        OnBeforeDownloadContent(ReportRun, TempBlob, IsHandled);
        if not IsHandled then
            DownloadContent(ReportRun."Download URL", UserName, Password, Setup."Max Report File Bytes", TempBlob);

        if TempBlob.Length() > Setup."Max Report File Bytes" then
            Error('The report exceeds the configured maximum of %1 bytes.', Setup."Max Report File Bytes");
        if TempBlob.Length() = 0 then
            Error('The downloaded report is empty.');

        TempBlob.CreateInStream(HashInStream);
        ReportRun."File Hash" := Crypto.GenerateStreamHash(HashInStream);
        TempBlob.CreateInStream(CopyInStream);
        ReportRun.Content.CreateOutStream(ReportOutStream);
        CopyStream(ReportOutStream, CopyInStream);
        ReportRun.Status := ReportRun.Status::Loading;
        ReportRun.Modify(true);
    end;

    [NonDebuggable]
    local procedure DownloadContent(DownloadUrl: Text; UserName: SecretText; Password: SecretText; MaximumBytes: Integer; var TempBlob: Codeunit "Temp Blob")
    var
        Base64Convert: Codeunit "Base64 Convert";
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Headers: HttpHeaders;
        ResponseInStream: InStream;
        TempOutStream: OutStream;
        UserAndPassword: SecretText;
        EncodedCredentials: SecretText;
        Authorization: SecretText;
    begin
        UserAndPassword := SecretStrSubstNo('%1:%2', UserName, Password);
        EncodedCredentials := Base64Convert.ToBase64(UserAndPassword);
        Authorization := SecretStrSubstNo('Basic %1', EncodedCredentials);
        Request.Method := 'GET';
        Request.SetRequestUri(DownloadUrl);
        Request.GetHeaders(Headers);
        Headers.Add('Authorization', Authorization);
        if not Client.Send(Request, Response) then
            Error('Business Central could not send the Adyen report request.');
        if not Response.IsSuccessStatusCode() then
            Error('Adyen report download failed with HTTP status %1 (%2).', Response.HttpStatusCode(), Response.ReasonPhrase());

        Response.Content.ReadAs(ResponseInStream);
        TempBlob.CreateOutStream(TempOutStream);
        CopyStream(TempOutStream, ResponseInStream, MaximumBytes + 1);
    end;

    procedure ValidateDownloadUrl(DownloadUrl: Text; AllowedHosts: Text)
    var
        Host: Text;
        AllowedHost: Text;
        HostCount: Integer;
        HostIndex: Integer;
    begin
        if CopyStr(LowerCase(DownloadUrl), 1, 8) <> 'https://' then
            Error('Adyen reports must be downloaded over HTTPS.');
        Host := ExtractHost(DownloadUrl);
        if Host = '' then
            Error('The Adyen report URL does not contain a host.');
        if StrPos(Host, ':') > 0 then
            Error('The Adyen report URL must not specify a custom port.');

        HostCount := 1 + StrLen(AllowedHosts) - StrLen(DelChr(AllowedHosts, '=', ','));
        for HostIndex := 1 to HostCount do begin
            AllowedHost := LowerCase(DelChr(SelectStr(HostIndex, AllowedHosts), '=', ' '));
            if HostMatches(Host, AllowedHost) then
                exit;
        end;
        Error('The Adyen report host %1 is not allowed.', Host);
    end;

    local procedure ExtractHost(DownloadUrl: Text): Text
    var
        HostAndPath: Text;
        DelimiterPosition: Integer;
        Index: Integer;
        Character: Text[1];
    begin
        HostAndPath := CopyStr(LowerCase(DownloadUrl), 9);
        DelimiterPosition := StrLen(HostAndPath) + 1;
        for Index := 1 to StrLen(HostAndPath) do begin
            Character := CopyStr(HostAndPath, Index, 1);
            if (Character in ['/', '?', '#']) and (Index < DelimiterPosition) then
                DelimiterPosition := Index;
        end;
        exit(CopyStr(HostAndPath, 1, DelimiterPosition - 1));
    end;

    local procedure HostMatches(Host: Text; AllowedHost: Text): Boolean
    begin
        if AllowedHost = '' then
            exit(false);
        if Host = AllowedHost then
            exit(true);
        if StrLen(Host) <= StrLen(AllowedHost) then
            exit(false);
        exit(CopyStr(Host, StrLen(Host) - StrLen(AllowedHost), StrLen(AllowedHost) + 1) = '.' + AllowedHost);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeDownloadContent(ReportRun: Record "Adyen Report Run"; var TempBlob: Codeunit "Temp Blob"; var IsHandled: Boolean)
    begin
    end;
}
