table 72003 "Adyen Event Entry"
{
    Caption = 'Adyen Event Entry';
    DataClassification = CustomerContent;
    LookupPageId = "Adyen Event Entries";
    DrillDownPageId = "Adyen Event Entries";

    fields
    {
        field(1; "Transport ID"; Code[64])
        {
            Caption = 'Transport ID';
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the unique SHA-256 identity of this transported webhook item or report row.';
        }
        field(2; "Logical Event Key"; Text[250])
        {
            Caption = 'Logical Event Key';
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the merchant-qualified identity used to recognize retransmissions of the same logical event.';
        }
        field(3; Source; Enum "Adyen Source")
        {
            Caption = 'Source';
            ToolTip = 'Specifies whether this event originated from a webhook notification or an accounting report.';
        }
        field(4; "Webhook Request Entry No."; BigInteger)
        {
            Caption = 'Webhook Request Entry No.';
            ToolTip = 'Specifies the webhook request entry from which this event was normalized, if applicable.';
        }
        field(5; "Report Run Entry No."; BigInteger)
        {
            Caption = 'Report Run Entry No.';
            ToolTip = 'Specifies the report run from which this event was normalized, if applicable.';
        }
        field(6; "Report Row No."; Integer)
        {
            Caption = 'Report Row No.';
            ToolTip = 'Specifies the source row number in the Adyen report, if this is a report event.';
        }
        field(7; "Report Row Identity"; Code[64])
        {
            Caption = 'Report Row Identity';
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the SHA-256 identity used to detect duplicate report rows.';
        }
        field(8; "Message Type"; Text[50])
        {
            Caption = 'Message Type';
            ToolTip = 'Specifies the normalized Adyen lifecycle event code or report status represented by this entry.';
        }
        field(9; "Occurred At UTC"; DateTime)
        {
            Caption = 'Occurred At UTC';
            ToolTip = 'Specifies the date and time in UTC when the payment event occurred in Adyen.';
        }
        field(10; "Received At UTC"; DateTime)
        {
            Caption = 'Received At UTC';
            ToolTip = 'Specifies the date and time in UTC when Business Central received or loaded this event.';
        }
        field(11; "Payload Hash"; Code[64])
        {
            Caption = 'Payload Hash';
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the hash of the source payload used for audit and duplicate detection.';
        }
        field(12; "Merchant Account"; Text[80])
        {
            Caption = 'Merchant Account';
            TableRelation = "Adyen Merchant"."Merchant Account";
            ToolTip = 'Specifies the Adyen merchant account to which the event belongs.';
        }
        field(13; "PSP Reference"; Text[50])
        {
            Caption = 'PSP Reference';
            ToolTip = 'Specifies the Adyen PSP reference that identifies this payment or lifecycle event.';
        }
        field(14; "Original PSP Reference"; Text[50])
        {
            Caption = 'Original PSP Reference';
            ToolTip = 'Specifies the original Adyen PSP reference affected by a follow-up lifecycle event.';
        }
        field(15; "Merchant Reference"; Text[80])
        {
            Caption = 'Merchant Reference';
            ToolTip = 'Specifies the merchant reference supplied to Adyen. It is retained for audit and is not used to force an invoice match.';
        }
        field(16; "Shopper Reference"; Text[250])
        {
            Caption = 'Shopper Reference';
            ToolTip = 'Specifies the shopper reference used as the direct Business Central customer-number candidate.';
        }
        field(17; "Payment Method"; Code[50])
        {
            Caption = 'Payment Method';
            ToolTip = 'Specifies the normalized Adyen payment method used to evaluate automatic-posting eligibility.';
        }
        field(18; "Success Provided"; Boolean)
        {
            Caption = 'Success Provided';
            ToolTip = 'Specifies whether the source event explicitly supplied a success value.';
        }
        field(19; Success; Boolean)
        {
            Caption = 'Success';
            ToolTip = 'Specifies the success value supplied by Adyen when one was present in the source event.';
        }
        field(20; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            ToolTip = 'Specifies the normalized currency code of the event amount.';
        }
        field(21; Amount; Decimal)
        {
            Caption = 'Amount';
            DecimalPlaces = 0 : 5;
            ToolTip = 'Specifies the monetary amount supplied by the Adyen event or report row.';
        }
        field(22; Reason; Text[2048])
        {
            Caption = 'Reason';
            ToolTip = 'Specifies the original reason text supplied by Adyen.';
        }
        field(23; Status; Enum "Adyen Process Status")
        {
            Caption = 'Status';
            ToolTip = 'Specifies whether the event is waiting, processing, processed, intentionally ignored, or in error.';
        }
        field(24; "Retry Count"; Integer)
        {
            Caption = 'Retry Count';
            Editable = false;
            ToolTip = 'Specifies how many processing attempts for this event have failed.';
        }
        field(25; "Last Error"; Text[2048])
        {
            Caption = 'Last Error';
            Editable = false;
            ToolTip = 'Specifies the most recent retryable processing error for this event.';
        }
        field(26; "Processed At UTC"; DateTime)
        {
            Caption = 'Processed At UTC';
            Editable = false;
            ToolTip = 'Specifies the date and time in UTC when processing of this event completed.';
        }
        field(27; "External Report ID"; Text[100])
        {
            Caption = 'External Report ID';
            ToolTip = 'Specifies the Adyen report identifier from which this event originated, if applicable.';
        }
        field(28; "Disposition Reason"; Text[250])
        {
            Caption = 'Disposition Reason';
            DataClassification = SystemMetadata;
            Editable = false;
            ToolTip = 'Specifies the Business Central decision that explains why the event was ignored or completed without changing a payment.';
        }
        field(29; "Payment PSP Reference"; Code[50])
        {
            Caption = 'Payment PSP Reference';
            DataClassification = CustomerContent;
            Editable = false;
            ToolTip = 'Specifies the original payment PSP reference affected by this event, using the event PSP reference when no original reference was supplied.';
        }
        field(30; "Previous Lifecycle Status"; Enum "Adyen Lifecycle Status")
        {
            Caption = 'Previous Lifecycle Status';
            DataClassification = SystemMetadata;
            Editable = false;
            ToolTip = 'Specifies the payment lifecycle status before this event was processed. Unknown means no payment lifecycle value was available at that point.';
        }
        field(31; "Resulting Lifecycle Status"; Enum "Adyen Lifecycle Status")
        {
            Caption = 'Resulting Lifecycle Status';
            DataClassification = SystemMetadata;
            Editable = false;
            ToolTip = 'Specifies the payment lifecycle status after this event was processed. Unknown means no payment lifecycle value was available at that point.';
        }
        field(32; "Lifecycle Effect"; Enum "Adyen Lifecycle Effect")
        {
            Caption = 'Lifecycle Effect';
            DataClassification = SystemMetadata;
            Editable = false;
            ToolTip = 'Specifies whether this event changed the payment lifecycle, was applied without a change, was not applied, or has no recorded processing outcome.';
        }
    }

    keys
    {
        key(PK; "Transport ID") { Clustered = true; }
        key(StatusKey; Status, "Occurred At UTC") { }
        key(LogicalKey; "Logical Event Key", "Occurred At UTC") { }
        key(RequestKey; "Webhook Request Entry No.") { }
        key(ReportKey; "Report Run Entry No.", Status) { }
        key(PaymentKey; "Merchant Account", "Payment PSP Reference", "Occurred At UTC") { }
        key(OccurredAtKey; "Occurred At UTC", "Transport ID") { }
    }

    trigger OnInsert()
    begin
        TestField("Transport ID");
        TestField("Logical Event Key");
        TestField("Message Type");
        TestField("Merchant Account");
        TestField("PSP Reference");
        if "Payment PSP Reference" = '' then
            if "Original PSP Reference" <> '' then
                "Payment PSP Reference" := CopyStr("Original PSP Reference", 1, MaxStrLen("Payment PSP Reference"))
            else
                "Payment PSP Reference" := CopyStr("PSP Reference", 1, MaxStrLen("Payment PSP Reference"));
        Status := Status::Received;
    end;
}
