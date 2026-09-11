table 72008 "Adyen Role Center Cue"
{
    Caption = 'Adyen Role Center Cue';
    DataClassification = CustomerContent;
    ReplicateData = false;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(2; "Payment Exceptions"; Integer)
        {
            CalcFormula = count("Imported Adyen Payment" where(Status = filter(Imported | Error | ReversalRequired | DataConflict)));
            Caption = 'Payment Exceptions';
            FieldClass = FlowField;
            ToolTip = 'Specifies the number of imported payments that require finance review because they are unmatched, errored, require reversal, or contain conflicting data.';
        }
        field(3; "Webhook Errors"; Integer)
        {
            CalcFormula = count("Adyen Webhook Request" where(Status = const(Error)));
            Caption = 'Webhook Errors';
            FieldClass = FlowField;
            ToolTip = 'Specifies the number of webhook requests that could not be normalized and can be reviewed for retry.';
        }
        field(4; "Event Errors"; Integer)
        {
            CalcFormula = count("Adyen Event Entry" where(Status = const(Error)));
            Caption = 'Event Errors';
            FieldClass = FlowField;
            ToolTip = 'Specifies the number of normalized Adyen events that failed during lifecycle, matching, or reconciliation processing.';
        }
        field(5; "Report Errors"; Integer)
        {
            CalcFormula = count("Adyen Report Run" where(Status = const(Error)));
            Caption = 'Report Errors';
            FieldClass = FlowField;
            ToolTip = 'Specifies the number of Adyen report runs that failed during download, loading, or reconciliation.';
        }
        field(6; "Ready to Post"; Integer)
        {
            CalcFormula = count("Imported Adyen Payment" where(Status = const(ReadyToPost)));
            Caption = 'Ready to Post';
            FieldClass = FlowField;
            ToolTip = 'Specifies the number of imported Adyen payments that passed matching checks and are ready to be posted and applied.';
        }
        field(7; "Manual Journal Drafts"; Integer)
        {
            CalcFormula = count("Imported Adyen Payment" where(Status = const(ManualJournalCreated)));
            Caption = 'Manual Journal Drafts';
            FieldClass = FlowField;
            ToolTip = 'Specifies the number of imported Adyen payments that have a linked manual payment-journal draft awaiting review or posting.';
        }
        field(9; "Pending Webhook Requests"; Integer)
        {
            CalcFormula = count("Adyen Webhook Request" where(Status = filter(Received | Processing)));
            Caption = 'Pending Webhook Requests';
            FieldClass = FlowField;
            ToolTip = 'Specifies the number of accepted webhook requests that are waiting for normalization or are currently being processed.';
        }
        field(10; "Pending Event Entries"; Integer)
        {
            CalcFormula = count("Adyen Event Entry" where(Status = filter(Received | Processing)));
            Caption = 'Pending Event Entries';
            FieldClass = FlowField;
            ToolTip = 'Specifies the number of normalized Adyen events that are waiting for lifecycle, matching, or reconciliation processing.';
        }
        field(11; "Active Report Runs"; Integer)
        {
            CalcFormula = count("Adyen Report Run" where(Status = filter(Requested | Downloading | Loading | Ready | Processing)));
            Caption = 'Active Report Runs';
            FieldClass = FlowField;
            ToolTip = 'Specifies the number of Adyen report runs that are requested, downloading, loading, ready, or being reconciled.';
        }
        field(12; "Overdue Merchants"; Integer)
        {
            CalcFormula = count("Adyen Merchant" where(Enabled = const(true), "Report Overdue" = const(true)));
            Caption = 'Overdue Merchants';
            FieldClass = FlowField;
            ToolTip = 'Specifies the number of enabled Adyen merchants whose expected daily accounting report is overdue.';
        }
        field(13; "Posted Adyen Payments"; Integer)
        {
            CalcFormula = count("Imported Adyen Payment" where("Posted Payment Entry No." = filter(<> 0)));
            Caption = 'Posted Adyen Payments';
            FieldClass = FlowField;
            ToolTip = 'Specifies the number of Adyen payments that have a linked posted customer ledger entry.';
        }
        field(14; "Automatically Posted"; Integer)
        {
            CalcFormula = count("Imported Adyen Payment" where("Posted Payment Entry No." = filter(<> 0), "Posting Origin" = const(Automatic)));
            Caption = 'Automatically Posted';
            FieldClass = FlowField;
            ToolTip = 'Specifies the number of posted Adyen payments that the extension posted automatically after finding a unique exact match.';
        }
        field(15; "Manually Posted"; Integer)
        {
            CalcFormula = count("Imported Adyen Payment" where("Posted Payment Entry No." = filter(<> 0), "Posting Origin" = filter(ManualExactMatch | ManualJournal)));
            Caption = 'Manually Posted';
            FieldClass = FlowField;
            ToolTip = 'Specifies the number of posted Adyen payments posted by a user through Post Exact Match or a reviewed manual journal.';
        }
        field(16; "Unclassified Posted"; Integer)
        {
            CalcFormula = count("Imported Adyen Payment" where("Posted Payment Entry No." = filter(<> 0), "Posting Origin" = const(Unclassified)));
            Caption = 'Unclassified Posted';
            FieldClass = FlowField;
            ToolTip = 'Specifies the number of posted Adyen payments for which no posting route has been recorded.';
        }
        field(17; "Total Imported Payments"; Integer)
        {
            CalcFormula = count("Imported Adyen Payment");
            Caption = 'Total Imported Payments';
            FieldClass = FlowField;
            ToolTip = 'Specifies the total number of Adyen payments imported into this company.';
        }
        field(18; "Adyen Tasks Failed"; Integer)
        {
            CalcFormula = count("Job Queue Entry" where("Object Type to Run" = const(Codeunit),
                                                         "Object ID to Run" = const(72044),
                                                         Status = const(Error)));
            Caption = 'Tasks Failed';
            FieldClass = FlowField;
            ToolTip = 'Specifies the number of Adyen dispatcher Job Queue entries that failed.';
        }
        field(19; "Adyen Tasks In Process"; Integer)
        {
            CalcFormula = count("Job Queue Entry" where("Object Type to Run" = const(Codeunit),
                                                         "Object ID to Run" = const(72044),
                                                         Status = const("In Process")));
            Caption = 'Tasks In Process';
            FieldClass = FlowField;
            ToolTip = 'Specifies the number of Adyen dispatcher Job Queue entries that are currently processing.';
        }
        field(20; "Adyen Tasks In Queue"; Integer)
        {
            CalcFormula = count("Job Queue Entry" where("Object Type to Run" = const(Codeunit),
                                                         "Object ID to Run" = const(72044),
                                                         Status = filter(Ready | Waiting)));
            Caption = 'Tasks In Queue';
            FieldClass = FlowField;
            ToolTip = 'Specifies the number of Adyen dispatcher Job Queue entries that are ready or waiting to run.';
        }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }
}
