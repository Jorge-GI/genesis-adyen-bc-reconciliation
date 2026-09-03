tableextension 72000 "Adyen Gen. Journal Line" extends "Gen. Journal Line"
{
    fields
    {
        field(72000; "Adyen Payment ID"; Guid)
        {
            Caption = 'Adyen Payment ID';
            DataClassification = SystemMetadata;
        }
    }
}
