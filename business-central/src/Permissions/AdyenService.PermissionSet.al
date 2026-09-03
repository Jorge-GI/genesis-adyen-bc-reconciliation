permissionset 72040 "ADYEN SERVICE"
{
    Assignable = true;
    Caption = 'Adyen API service';

    Permissions =
        tabledata "Adyen Setup" = R,
        tabledata "Adyen Inbox Entry" = RIM,
        tabledata "Adyen Report Run" = RIM,
        table "Adyen Inbox Entry" = X,
        table "Adyen Report Run" = X,
        page "Adyen Inbound Messages API" = X,
        page "Adyen Report Runs API" = X;
}
