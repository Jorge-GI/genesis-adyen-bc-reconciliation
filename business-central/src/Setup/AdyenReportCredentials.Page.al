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
            }
            field(Password; Password)
            {
                ApplicationArea = All;
                Caption = 'Password';
                ExtendedDatatype = Masked;
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
