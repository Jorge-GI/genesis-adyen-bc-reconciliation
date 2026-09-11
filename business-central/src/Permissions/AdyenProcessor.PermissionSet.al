permissionset 72061 "ADYEN PROCESSOR"
{
    Assignable = true;
    Caption = 'Adyen background processor';

    Permissions =
        tabledata "Adyen Setup" = RM,
        tabledata "Adyen Merchant" = RM,
        tabledata "Adyen Webhook Request" = RM,
        tabledata "Adyen Event Entry" = RIM,
        tabledata "Adyen Report Run" = RIM,
        tabledata "Imported Adyen Payment" = RIM,
        tabledata "Adyen Merchant Method Policy" = R,
        tabledata "Gen. Journal Line" = RIMD,
        tabledata "Cust. Ledger Entry" = R,
        tabledata "Detailed Cust. Ledg. Entry" = R,
        tabledata Customer = R,
        tabledata Currency = R,
        tabledata "General Ledger Setup" = R,
        tabledata "Gen. Journal Template" = R,
        tabledata "Gen. Journal Batch" = R,
        tabledata "G/L Account" = R,
        codeunit "Adyen Credentials" = X,
        codeunit "Adyen Cryptography" = X,
        codeunit "Adyen Money" = X,
        codeunit "Adyen Webhook Intake" = X,
        codeunit "Adyen Payment State" = X,
        codeunit "Adyen Invoice Matcher" = X,
        codeunit "Adyen Payment Poster" = X,
        codeunit "Adyen Report Downloader" = X,
        codeunit "Adyen Report Parser" = X,
        codeunit "Adyen Report Reconciler" = X,
        codeunit "Adyen Report Management" = X,
        codeunit "Adyen Dispatcher" = X,
        codeunit "Adyen Retention" = X,
        codeunit "Adyen Webhook Worker" = X,
        codeunit "Adyen Report Worker" = X,
        codeunit "Adyen Event Worker" = X,
        codeunit "Adyen Event Disposition" = X,
        codeunit "Gen. Jnl.-Post Line" = X;
}
