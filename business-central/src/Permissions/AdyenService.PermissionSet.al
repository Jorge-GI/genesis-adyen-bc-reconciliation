permissionset 72060 "ADYEN SERVICE"
{
    Assignable = true;
    Caption = 'Adyen webhook submitter';

    Permissions =
        table "Adyen Webhook Request" = X,
        codeunit "Adyen Credentials" = X,
        codeunit "Adyen Cryptography" = X,
        codeunit "Adyen Webhook Intake" = X,
        page "Adyen Webhook Requests API" = X;
}
