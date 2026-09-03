enum 72004 "Adyen Match Result"
{
    Extensible = false;

    value(0; NotRun) { Caption = 'Not run'; }
    value(1; UniqueExact) { Caption = 'Unique exact'; }
    value(2; None) { Caption = 'No match'; }
    value(3; Multiple) { Caption = 'Multiple matches'; }
    value(4; InvalidCustomer) { Caption = 'Invalid customer'; }
    value(5; UnsupportedMethod) { Caption = 'Unsupported payment method'; }
}
