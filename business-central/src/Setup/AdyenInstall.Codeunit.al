codeunit 72047 "Adyen Install"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        Setup: Record "Adyen Setup";
        Credentials: Codeunit "Adyen Credentials";
    begin
        Setup.GetRecordOnce();
        Credentials.UpdateFlags();
    end;
}
