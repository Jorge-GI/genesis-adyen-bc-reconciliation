table 72005 "Imported Adyen Payment"
{
    Caption = 'Imported Adyen Payment';
    DataClassification = CustomerContent;
    LookupPageId = "Imported Adyen Payments";
    DrillDownPageId = "Imported Adyen Payments";

    fields
    {
        field(1; "Merchant Account"; Text[80])
        {
            Caption = 'Merchant Account';
            TableRelation = "Adyen Merchant"."Merchant Account";
            Editable = false;
            ToolTip = 'Specifies the Adyen merchant account to which this payment belongs.';
        }
        field(2; "PSP Reference"; Code[50])
        {
            Caption = 'PSP Reference';
            Editable = false;
            ToolTip = 'Specifies the original Adyen PSP reference that uniquely identifies this payment within the merchant account.';
        }
        field(3; "Merchant Reference"; Text[80])
        {
            Caption = 'Merchant Reference';
            Editable = false;
            ToolTip = 'Specifies the merchant reference supplied to Adyen. It is retained for audit and is not used to force an invoice match.';
        }
        field(4; "Shopper Reference"; Text[250])
        {
            Caption = 'Shopper Reference';
            Editable = false;
            ToolTip = 'Specifies the shopper reference received from Adyen and used as the direct customer-number candidate.';
        }
        field(5; "Resolved Customer No."; Code[20])
        {
            Caption = 'Resolved Customer No.';
            TableRelation = Customer."No.";
            ToolTip = 'Specifies the Business Central customer used for matching. Finance users can set this value to override an unresolved shopper reference before re-evaluating the match.';
        }
        field(6; "Payment Method"; Code[50])
        {
            Caption = 'Payment Method';
            Editable = false;
            ToolTip = 'Specifies the normalized Adyen payment method used to evaluate the merchant-specific automatic-posting policy.';
        }
        field(7; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            TableRelation = Currency.Code;
            Editable = false;
            ToolTip = 'Specifies the normalized currency code of the imported payment.';
        }
        field(8; Amount; Decimal)
        {
            Caption = 'Amount';
            DecimalPlaces = 0 : 5;
            Editable = false;
            ToolTip = 'Specifies the amount received for this Adyen payment.';
        }
        field(9; "Event Date-Time"; DateTime)
        {
            Caption = 'Event Date-Time';
            Editable = false;
            ToolTip = 'Specifies the date and time reported by Adyen for the original payment event.';
        }
        field(10; "Latest Event At UTC"; DateTime)
        {
            Caption = 'Latest Event At UTC';
            Editable = false;
            ToolTip = 'Specifies the date and time in UTC of the latest lifecycle event applied to this payment.';
        }
        field(11; "Latest Logical Event Key"; Text[250])
        {
            Caption = 'Latest Logical Event Key';
            DataClassification = SystemMetadata;
            Editable = false;
            ToolTip = 'Specifies the identity of the latest logical event applied to this payment for audit and conflict detection.';
        }
        field(12; "Origin Source"; Enum "Adyen Source")
        {
            Caption = 'Origin Source';
            Editable = false;
            ToolTip = 'Specifies whether the payment was first created from a webhook notification or backfilled from a report.';
        }
        field(13; Status; Enum "Adyen Payment Status")
        {
            Caption = 'Status';
            Editable = false;
            ToolTip = 'Specifies the current matching, posting, manual-review, reversal, or conflict state of the payment.';
        }
        field(14; "Status Before Manual"; Enum "Adyen Payment Status")
        {
            Caption = 'Status Before Manual';
            Editable = false;
            ToolTip = 'Specifies the payment status retained before a manual journal draft was created so it can be restored if the draft is deleted.';
        }
        field(15; "Match Result"; Enum "Adyen Match Result")
        {
            Caption = 'Match Result';
            Editable = false;
            ToolTip = 'Specifies the result of matching the customer, currency, amount, payment-method policy, and open invoice.';
        }
        field(17; "Matched Invoice Entry No."; Integer)
        {
            Caption = 'Matched Invoice Entry No.';
            TableRelation = "Cust. Ledger Entry"."Entry No.";
            Editable = false;
            ToolTip = 'Specifies the customer ledger entry number of the uniquely matched open invoice.';
        }
        field(18; "Posted Payment Entry No."; Integer)
        {
            Caption = 'Posted Payment Entry No.';
            TableRelation = "Cust. Ledger Entry"."Entry No.";
            Editable = false;
            ToolTip = 'Specifies the customer ledger entry number created when this payment was posted.';
        }
        field(19; "Manual Journal Template"; Code[10])
        {
            Caption = 'Manual Journal Template';
            Editable = false;
            ToolTip = 'Specifies the journal template containing the manual draft linked to this payment.';
        }
        field(20; "Manual Journal Batch"; Code[10])
        {
            Caption = 'Manual Journal Batch';
            Editable = false;
            ToolTip = 'Specifies the journal batch containing the manual draft linked to this payment.';
        }
        field(21; "Manual Journal Line No."; Integer)
        {
            Caption = 'Manual Journal Line No.';
            Editable = false;
            ToolTip = 'Specifies the line number of the manual payment journal draft linked to this payment.';
        }
        field(22; "Exception Message"; Text[2048])
        {
            Caption = 'Exception Message';
            Editable = false;
            ToolTip = 'Specifies why this payment requires attention or could not be matched, posted, or reconciled automatically.';
        }
        field(23; Backfilled; Boolean)
        {
            Caption = 'Backfilled from report';
            Editable = false;
            ToolTip = 'Specifies whether this payment was created from an accounting report because no earlier webhook payment existed.';
        }
        field(24; "Created At UTC"; DateTime)
        {
            Caption = 'Created At UTC';
            Editable = false;
            ToolTip = 'Specifies the date and time in UTC when the imported payment record was created.';
        }
        field(25; "Modified At UTC"; DateTime)
        {
            Caption = 'Modified At UTC';
            Editable = false;
            ToolTip = 'Specifies the date and time in UTC when the imported payment record was last changed.';
        }
        field(26; "Adyen Lifecycle Status"; Enum "Adyen Lifecycle Status")
        {
            Caption = 'Adyen Lifecycle Status';
            Editable = false;
            ToolTip = 'Specifies the latest supported Adyen payment lifecycle state applied from a webhook or Payment Accounting Report event.';
        }
        field(27; "Posting Origin"; Enum "Adyen Posting Origin")
        {
            Caption = 'Posting Origin';
            Editable = false;
            ToolTip = 'Specifies whether the Adyen payment was posted automatically, by the Post Exact Match action, or through a manually reviewed journal. Unclassified means no posting route has been recorded.';
        }
    }

    keys
    {
        key(PK; "Merchant Account", "PSP Reference") { Clustered = true; }
        key(StatusKey; Status) { }
        key(CustomerKey; "Resolved Customer No.", Status) { }
        key(PostedPaymentKey; "Posted Payment Entry No.", "Posting Origin") { }
        key(LatestEventKey; "Latest Event At UTC", "Merchant Account", "PSP Reference") { }
        key(CreatedAtKey; "Created At UTC", "Merchant Account", "PSP Reference") { }
    }

    trigger OnInsert()
    begin
        TestField("Merchant Account");
        TestField("PSP Reference");
        "Created At UTC" := CurrentDateTime();
        "Modified At UTC" := "Created At UTC";
    end;

    trigger OnModify()
    begin
        "Modified At UTC" := CurrentDateTime();
    end;
}
