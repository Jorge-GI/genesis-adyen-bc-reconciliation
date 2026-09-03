permissionset 72042 "ADYEN ADMIN"
{
    Assignable = true;
    Caption = 'Adyen administrator';

    Permissions =
        tabledata "Adyen Setup" = RIMD,
        tabledata "Adyen Inbox Entry" = RIMD,
        tabledata "Adyen Report Run" = RIMD,
        tabledata "Imported Adyen Payment" = RIMD,
        tabledata "Adyen Payment Method Policy" = RIMD,
        table "Adyen Setup" = X,
        table "Adyen Inbox Entry" = X,
        table "Adyen Report Run" = X,
        table "Imported Adyen Payment" = X,
        table "Adyen Payment Method Policy" = X,
        codeunit "Adyen Job Queue Setup" = X,
        page "Adyen Setup" = X,
        page "Adyen Payment Method Policies" = X,
        page "Imported Adyen Payments" = X,
        page "Adyen Payment Exceptions" = X,
        page "Adyen Inbox Entries" = X,
        page "Adyen Report Runs" = X;
}
