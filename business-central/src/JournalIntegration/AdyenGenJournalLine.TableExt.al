tableextension 72000 "Adyen Gen. Journal Line" extends "Gen. Journal Line"
{
    fields
    {
        field(72000; "Adyen Payment ID"; Guid)
        {
            Caption = 'Adyen Payment ID';
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the system identifier of the imported Adyen payment linked to this journal line.';
        }
        field(72001; "Adyen Posting Origin"; Enum "Adyen Posting Origin")
        {
            Caption = 'Adyen Posting Origin';
            DataClassification = SystemMetadata;
            Editable = false;
            ToolTip = 'Specifies the Adyen workflow that created this payment journal line so the origin can be retained when it is posted.';
        }
    }
}
