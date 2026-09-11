page 72019 "Adyen Report Credentials"
{
    PageType = StandardDialog;
    Caption = 'Set Adyen Report Credentials';
    Extensible = false;

    layout
    {
        area(Content)
        {
            field(UserName; UserName)
            {
                ApplicationArea = All;
                Caption = 'User Name';
                ToolTip = 'Specifies the user name for the Adyen report Basic Auth account.';
            }
            field(Password; Password)
            {
                ApplicationArea = All;
                Caption = 'Password';
                ExtendedDatatype = Masked;
                ToolTip = 'Specifies the password for the Adyen report Basic Auth account. The password is masked and cannot be read back after it is saved.';
            }
        }
    }

    var
        [NonDebuggable]
        UserName: Text;
        [NonDebuggable]
        Password: Text;

    [NonDebuggable]
    procedure GetUserName(): Text
    begin
        exit(UserName);
    end;

    [NonDebuggable]
    procedure GetPassword(): Text
    begin
        exit(Password);
    end;
}
