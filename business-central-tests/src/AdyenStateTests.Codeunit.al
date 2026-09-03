codeunit 72150 "Adyen State Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure CaptureFailedIsAdverse()
    var
        PaymentState: Codeunit "Adyen Payment State Mgt.";
    begin
        if not PaymentState.IsAdverseMessage('CAPTURE_FAILED') then
            Error('CAPTURE_FAILED must be classified as adverse.');
    end;

    [Test]
    procedure AuthorisationIsNotAdverse()
    var
        PaymentState: Codeunit "Adyen Payment State Mgt.";
    begin
        if PaymentState.IsAdverseMessage('AUTHORISATION') then
            Error('AUTHORISATION must not be classified as adverse.');
    end;
}
