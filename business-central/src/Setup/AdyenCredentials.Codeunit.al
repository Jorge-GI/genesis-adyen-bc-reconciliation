codeunit 72031 "Adyen Credentials"
{
    var
        CurrentHmacKeyLbl: Label 'adyen-hmac-current', Locked = true;
        PreviousHmacKeyLbl: Label 'adyen-hmac-previous', Locked = true;
        ReportUserLbl: Label 'adyen-report-user', Locked = true;
        ReportPasswordLbl: Label 'adyen-report-password', Locked = true;

    [NonDebuggable]
    procedure SetCurrentHmacHex(HexKey: Text)
    var
        Crypto: Codeunit "Adyen Cryptography";
        EncodedKey: SecretText;
    begin
        EncodedKey := Crypto.HexToBase64(HexKey);
        IsolatedStorage.SetEncrypted(CurrentHmacKeyLbl, EncodedKey, DataScope::Company);
        UpdateFlags();
    end;

    [NonDebuggable]
    procedure SetPreviousHmacHex(HexKey: Text)
    var
        Crypto: Codeunit "Adyen Cryptography";
        EncodedKey: SecretText;
    begin
        EncodedKey := Crypto.HexToBase64(HexKey);
        IsolatedStorage.SetEncrypted(PreviousHmacKeyLbl, EncodedKey, DataScope::Company);
        UpdateFlags();
    end;

    [NonDebuggable]
    procedure RotateCurrentHmacHex(NewHexKey: Text)
    var
        CurrentKey: SecretText;
    begin
        if IsolatedStorage.Get(CurrentHmacKeyLbl, DataScope::Company, CurrentKey) then
            IsolatedStorage.SetEncrypted(PreviousHmacKeyLbl, CurrentKey, DataScope::Company);
        SetCurrentHmacHex(NewHexKey);
    end;

    procedure TestConfiguration()
    var
        Setup: Record "Adyen Setup";
        SecretValue: SecretText;
    begin
        Setup.GetRecordOnce();
        Setup.TestField("HMAC Key Configured", true);
        if not GetCurrentHmacKey(SecretValue) then
            Error('The current HMAC key could not be read from encrypted storage.');
        Setup.TestField("Report Credentials Configured", true);
        if not GetReportUser(SecretValue) then
            Error('The report user could not be read from encrypted storage.');
        if not GetReportPassword(SecretValue) then
            Error('The report password could not be read from encrypted storage.');
    end;

    [NonDebuggable]
    procedure SetReportCredentials(UserName: Text; Password: Text)
    var
        SecretUserName: SecretText;
        SecretPassword: SecretText;
    begin
        if UserName = '' then
            Error('The report user name is required.');
        if Password = '' then
            Error('The report password is required.');
        SecretUserName := UserName;
        SecretPassword := Password;
        IsolatedStorage.SetEncrypted(ReportUserLbl, SecretUserName, DataScope::Company);
        IsolatedStorage.SetEncrypted(ReportPasswordLbl, SecretPassword, DataScope::Company);
        UpdateFlags();
    end;

    procedure ClearCurrentHmac()
    begin
        if IsolatedStorage.Contains(CurrentHmacKeyLbl, DataScope::Company) then
            IsolatedStorage.Delete(CurrentHmacKeyLbl, DataScope::Company);
        UpdateFlags();
    end;

    procedure ClearPreviousHmac()
    begin
        if IsolatedStorage.Contains(PreviousHmacKeyLbl, DataScope::Company) then
            IsolatedStorage.Delete(PreviousHmacKeyLbl, DataScope::Company);
        UpdateFlags();
    end;

    procedure ClearReportCredentials()
    begin
        if IsolatedStorage.Contains(ReportUserLbl, DataScope::Company) then
            IsolatedStorage.Delete(ReportUserLbl, DataScope::Company);
        if IsolatedStorage.Contains(ReportPasswordLbl, DataScope::Company) then
            IsolatedStorage.Delete(ReportPasswordLbl, DataScope::Company);
        UpdateFlags();
    end;

    [NonDebuggable]
    procedure GetCurrentHmacKey(var Value: SecretText): Boolean
    begin
        exit(IsolatedStorage.Get(CurrentHmacKeyLbl, DataScope::Company, Value));
    end;

    [NonDebuggable]
    procedure GetPreviousHmacKey(var Value: SecretText): Boolean
    begin
        exit(IsolatedStorage.Get(PreviousHmacKeyLbl, DataScope::Company, Value));
    end;

    [NonDebuggable]
    procedure GetReportUser(var Value: SecretText): Boolean
    begin
        exit(IsolatedStorage.Get(ReportUserLbl, DataScope::Company, Value));
    end;

    [NonDebuggable]
    procedure GetReportPassword(var Value: SecretText): Boolean
    begin
        exit(IsolatedStorage.Get(ReportPasswordLbl, DataScope::Company, Value));
    end;

    procedure UpdateFlags()
    var
        Setup: Record "Adyen Setup";
    begin
        Setup.GetRecordOnce();
        Setup."HMAC Key Configured" := IsolatedStorage.Contains(CurrentHmacKeyLbl, DataScope::Company);
        Setup."Previous HMAC Configured" := IsolatedStorage.Contains(PreviousHmacKeyLbl, DataScope::Company);
        Setup."Report Credentials Configured" :=
            IsolatedStorage.Contains(ReportUserLbl, DataScope::Company) and
            IsolatedStorage.Contains(ReportPasswordLbl, DataScope::Company);
        Setup.Modify(true);
    end;
}
