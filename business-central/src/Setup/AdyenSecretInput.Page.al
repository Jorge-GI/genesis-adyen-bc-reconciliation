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
