codeunit 72038 "Adyen Install"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        Setup: Record "Adyen Setup";
    begin
        Setup.GetRecordOnce();
    end;
}
