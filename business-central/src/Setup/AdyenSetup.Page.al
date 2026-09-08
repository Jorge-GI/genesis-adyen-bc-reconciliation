page 72010 "Adyen Setup"
{
    PageType = Card;
    Caption = 'Adyen Setup';
    SourceTable = "Adyen Setup";
    UsageCategory = Administration;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field(Enabled; Rec.Enabled) { ApplicationArea = All; }
                field(Environment; Rec.Environment) { ApplicationArea = All; }
                field("Max Messages Per Run"; Rec."Max Messages Per Run") { ApplicationArea = All; }
            }
            group(Security)
            {
                Caption = 'Security and Report Access';
                field("HMAC Key Configured"; Rec."HMAC Key Configured") { ApplicationArea = All; }
                field("Previous HMAC Configured"; Rec."Previous HMAC Configured") { ApplicationArea = All; }
                field("Report Credentials Configured"; Rec."Report Credentials Configured") { ApplicationArea = All; }
                field("Allowed Report Hosts"; Rec."Allowed Report Hosts") { ApplicationArea = All; }
                field("Max Webhook Payload Bytes"; Rec."Max Webhook Payload Bytes") { ApplicationArea = All; }
                field("Max Report File Bytes"; Rec."Max Report File Bytes") { ApplicationArea = All; }
            }
            group(Operations)
            {
                Caption = 'Operations';
                field("Report Deadline"; Rec."Report Deadline") { ApplicationArea = All; }
                field("Raw Retention Days"; Rec."Raw Retention Days") { ApplicationArea = All; }
                field("Report Retention Months"; Rec."Report Retention Months") { ApplicationArea = All; }
                field("Last Cleanup At UTC"; Rec."Last Cleanup At UTC") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SetCurrentHmac)
            {
                Caption = 'Set Current HMAC Key';
                ApplicationArea = All;
                Image = EncryptionKeys;

                trigger OnAction()
                var
                    SecretInput: Page "Adyen Secret Input";
                    Credentials: Codeunit "Adyen Credentials";
                begin
                    if SecretInput.RunModal() <> Action::OK then
                        exit;
                    Credentials.SetCurrentHmacHex(SecretInput.GetValue());
                    CurrPage.Update(false);
                end;
            }
            action(RotateHmac)
            {
                Caption = 'Rotate HMAC Key';
                ApplicationArea = All;
                Image = Change;

                trigger OnAction()
                var
                    SecretInput: Page "Adyen Secret Input";
                    Credentials: Codeunit "Adyen Credentials";
                begin
                    if SecretInput.RunModal() <> Action::OK then
                        exit;
                    Credentials.RotateCurrentHmacHex(SecretInput.GetValue());
                    CurrPage.Update(false);
                end;
            }
            action(SetReportCredentials)
            {
                Caption = 'Set Report Credentials';
                ApplicationArea = All;
                Image = EncryptionKeys;

                trigger OnAction()
                var
                    CredentialDialog: Page "Adyen Report Credentials";
                    Credentials: Codeunit "Adyen Credentials";
                begin
                    if CredentialDialog.RunModal() <> Action::OK then
                        exit;
                    Credentials.SetReportCredentials(CredentialDialog.GetUserName(), CredentialDialog.GetPassword());
                    CurrPage.Update(false);
                end;
            }
            action(TestCredentials)
            {
                Caption = 'Test Stored Credentials';
                ApplicationArea = All;
                Image = TestDatabase;

                trigger OnAction()
                var
                    Credentials: Codeunit "Adyen Credentials";
                begin
                    Credentials.TestConfiguration();
                    Message('The encrypted credentials are present and readable. Use a report retry to validate the remote Adyen login.');
                end;
            }
            action(ClearPreviousHmac)
            {
                Caption = 'Clear Previous HMAC Key';
                ApplicationArea = All;
                Image = Delete;

                trigger OnAction()
                var
                    Credentials: Codeunit "Adyen Credentials";
                begin
                    if Confirm('Clear the previous HMAC key?') then begin
                        Credentials.ClearPreviousHmac();
                        CurrPage.Update(false);
                    end;
                end;
            }
            action(ClearCurrentHmac)
            {
                Caption = 'Clear Current HMAC Key';
                ApplicationArea = All;
                Image = Delete;

                trigger OnAction()
                var
                    Credentials: Codeunit "Adyen Credentials";
                begin
                    if Confirm('Clear the current HMAC key? New webhook requests will be rejected until another key is set.') then begin
                        Credentials.ClearCurrentHmac();
                        CurrPage.Update(false);
                    end;
                end;
            }
            action(ClearReportCredentials)
            {
                Caption = 'Clear Report Credentials';
                ApplicationArea = All;
                Image = Delete;

                trigger OnAction()
                var
                    Credentials: Codeunit "Adyen Credentials";
                begin
                    if Confirm('Clear the Adyen report credentials?') then begin
                        Credentials.ClearReportCredentials();
                        CurrPage.Update(false);
                    end;
                end;
            }
            action(CreateJobQueueEntry)
            {
                Caption = 'Create Job Queue Entry';
                ApplicationArea = All;
                Image = Job;

                trigger OnAction()
                var
                    JobQueueSetup: Codeunit "Adyen Job Queue Setup";
                begin
                    JobQueueSetup.EnsureEntry();
                end;
            }
            action(RunRetention)
            {
                Caption = 'Run Retention Cleanup';
                ApplicationArea = All;
                Image = DeleteExpiredComponents;

                trigger OnAction()
                var
                    Retention: Codeunit "Adyen Retention";
                begin
                    Retention.RunCleanup();
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.GetRecordOnce();
    end;
}
