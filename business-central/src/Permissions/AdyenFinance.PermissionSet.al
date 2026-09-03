permissionset 72041 "ADYEN FINANCE"
{
    Assignable = true;
    Caption = 'Adyen finance operator';

    Permissions =
        tabledata "Adyen Setup" = R,
        tabledata "Adyen Inbox Entry" = RM,
        tabledata "Adyen Report Run" = R,
        tabledata "Imported Adyen Payment" = RIM,
        tabledata "Adyen Payment Method Policy" = R,
        tabledata "Gen. Journal Line" = RIMD,
        tabledata "Cust. Ledger Entry" = R,
        tabledata Customer = R,
        tabledata "General Ledger Setup" = R,
        codeunit "Adyen Inbox Dispatcher" = X,
        codeunit "Adyen Invoice Matcher" = X,
        codeunit "Adyen Payment Poster" = X,
        codeunit "Adyen Payment State Mgt." = X,
        codeunit "Adyen Report Reconciler" = X,
        codeunit "Adyen Manual Journal Mgt." = X,
        page "Imported Adyen Payments" = X,
        page "Adyen Payment Exceptions" = X,
        page "Adyen Inbox Entries" = X,
        page "Adyen Report Runs" = X;
}
