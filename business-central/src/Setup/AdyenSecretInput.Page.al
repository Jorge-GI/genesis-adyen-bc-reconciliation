page 72018 "Adyen Secret Input"
{
    PageType = StandardDialog;
    Caption = 'Enter Secret';
    Extensible = false;

    layout
    {
        area(Content)
        {
            field(SecretValue; SecretValue)
            {
                ApplicationArea = All;
                Caption = 'Value';
                ExtendedDatatype = Masked;
                ToolTip = 'Specifies the secret value to store securely. The value is masked while entered and cannot be read back after it is saved.';
            }
        }
    }

    var
        [NonDebuggable]
        SecretValue: Text;

    [NonDebuggable]
    procedure GetValue(): Text
    begin
        exit(SecretValue);
    end;
}
