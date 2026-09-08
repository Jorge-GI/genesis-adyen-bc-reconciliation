permissionset 72062 "ADYEN FINANCE"
{
    Assignable = true;
    Caption = 'Adyen finance operator';

    Permissions =
        tabledata "Adyen Setup" = R,
        tabledata "Adyen Merchant" = R,
        tabledata "Adyen Webhook Request" = RM,
        tabledata "Adyen Event Entry" = RM,
        tabledata "Adyen Report Run" = RM,
        tabledata "Imported Adyen Payment" = RM,
        tabledata "Adyen Payment Method Policy" = R,
        tabledata "Gen. Journal Line" = RIMD,
        tabledata "Cust. Ledger Entry" = R,
        tabledata "Detailed Cust. Ledg. Entry" = R,
        tabledata Customer = R,
        tabledata Currency = R,
        tabledata "General Ledger Setup" = R,
        tabledata "Gen. Journal Template" = R,
        tabledata "Gen. Journal Batch" = R,
        tabledata "G/L Account" = R,
        codeunit "Adyen Invoice Matcher" = X,
        codeunit "Adyen Payment Poster" = X,
        codeunit "Adyen Manual Journal" = X,
        codeunit "Gen. Jnl.-Post Line" = X,
        page "Adyen Webhook Requests" = X,
        page "Adyen Event Entries" = X,
        page "Imported Adyen Payments" = X,
        page "Adyen Payment Exceptions" = X,
        page "Adyen Report Runs" = X;
}
