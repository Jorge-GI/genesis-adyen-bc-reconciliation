table 72000 "Adyen Setup"
{
    Caption = 'Adyen Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(2; Enabled; Boolean) { Caption = 'Enabled'; }
        field(3; Environment; Enum "Adyen Environment") { Caption = 'Environment'; }
        field(4; "Allowed Report Hosts"; Text[250])
        {
            Caption = 'Allowed Report Hosts';
            ToolTip = 'Specifies a comma-separated list of Adyen hosts from which report files may be downloaded.';
        }
        field(5; "Max Webhook Payload Bytes"; Integer)
        {
            Caption = 'Maximum Webhook Payload Bytes';
            MinValue = 1024;
        }
        field(6; "Max Report File Bytes"; Integer)
        {
            Caption = 'Maximum Report File Bytes';
            MinValue = 1024;
        }
        field(7; "Report Deadline"; Time) { Caption = 'Daily Report Deadline'; }
        field(8; "Raw Retention Days"; Integer)
        {
            Caption = 'Raw Webhook Retention Days';
            MinValue = 1;
        }
        field(9; "Report Retention Months"; Integer)
        {
            Caption = 'Report File Retention Months';
            MinValue = 1;
        }
        field(10; "Max Messages Per Run"; Integer)
        {
            Caption = 'Maximum Messages per Run';
            MinValue = 1;
            MaxValue = 500;
        }
        field(11; "HMAC Key Configured"; Boolean)
        {
            Caption = 'Current HMAC Key Configured';
            Editable = false;
            DataClassification = SystemMetadata;
        }
        field(12; "Previous HMAC Configured"; Boolean)
        {
            Caption = 'Previous HMAC Key Configured';
            Editable = false;
            DataClassification = SystemMetadata;
        }
        field(13; "Report Credentials Configured"; Boolean)
        {
            Caption = 'Report Credentials Configured';
            Editable = false;
            DataClassification = SystemMetadata;
        }
        field(14; "Last Cleanup At UTC"; DateTime)
        {
            Caption = 'Last Cleanup At UTC';
            Editable = false;
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }

    trigger OnInsert()
    begin
        if "Allowed Report Hosts" = '' then
            "Allowed Report Hosts" := 'ca-test.adyen.com,ca-live.adyen.com';
        if "Max Webhook Payload Bytes" = 0 then
            "Max Webhook Payload Bytes" := 1048576;
        if "Max Report File Bytes" = 0 then
            "Max Report File Bytes" := 52428800;
        if "Report Deadline" = 0T then
            "Report Deadline" := 120000T;
        if "Raw Retention Days" = 0 then
            "Raw Retention Days" := 90;
        if "Report Retention Months" = 0 then
            "Report Retention Months" := 13;
        if "Max Messages Per Run" = 0 then
            "Max Messages Per Run" := 50;
    end;

    procedure GetRecordOnce()
    begin
        if not Get('SETUP') then begin
            Init();
            "Primary Key" := 'SETUP';
            Insert(true);
        end;
    end;

    procedure ValidateForIntake()
    begin
        TestField(Enabled, true);
        TestField("HMAC Key Configured", true);
        TestField("Max Webhook Payload Bytes");
    end;

    procedure ValidateForReportDownload()
    begin
        ValidateForIntake();
        TestField("Report Credentials Configured", true);
        TestField("Allowed Report Hosts");
        TestField("Max Report File Bytes");
    end;
}
