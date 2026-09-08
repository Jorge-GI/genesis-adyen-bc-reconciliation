codeunit 72038 "Adyen Manual Journal"
{
    procedure CreateDraft(var Payment: Record "Imported Adyen Payment"; var GenJournalLine: Record "Gen. Journal Line")
    var
        Merchant: Record "Adyen Merchant";
        Customer: Record Customer;
        NextLineNo: Integer;
    begin
        if not (Payment.Status in [Payment.Status::Imported, Payment.Status::Error, Payment.Status::ReadyToPost]) then
            Error('Payment %1 for merchant %2 is not eligible for a manual journal draft.', Payment."PSP Reference", Payment."Merchant Account");
        Merchant.Get(Payment."Merchant Account");
        Merchant.ValidateForPosting();
        Payment.TestField("Posted Payment Entry No.", 0);
        Payment.TestField("Resolved Customer No.");
        Customer.Get(Payment."Resolved Customer No.");
        if Customer.Blocked <> Customer.Blocked::" " then
            Error('Customer %1 is blocked.', Customer."No.");

        if (Payment."Manual Journal Line No." <> 0) and
           GenJournalLine.Get(Payment."Manual Journal Template", Payment."Manual Journal Batch", Payment."Manual Journal Line No.")
        then
            exit;

        GenJournalLine.Reset();
        GenJournalLine.SetRange("Journal Template Name", Merchant."Journal Template Name");
        GenJournalLine.SetRange("Journal Batch Name", Merchant."Manual Journal Batch Name");
        if GenJournalLine.FindLast() then
            NextLineNo := GenJournalLine."Line No." + 10000
        else
            NextLineNo := 10000;

        GenJournalLine.Init();
        GenJournalLine.Validate("Journal Template Name", Merchant."Journal Template Name");
        GenJournalLine.Validate("Journal Batch Name", Merchant."Manual Journal Batch Name");
        GenJournalLine."Line No." := NextLineNo;
        GenJournalLine.Validate("Posting Date", DT2Date(Payment."Event Date-Time"));
        GenJournalLine.Validate("Document Type", GenJournalLine."Document Type"::Payment);
        GenJournalLine.Validate("Document No.", CopyStr(Payment."PSP Reference", 1, MaxStrLen(GenJournalLine."Document No.")));
        GenJournalLine.Validate("External Document No.", CopyStr(Payment."PSP Reference", 1, MaxStrLen(GenJournalLine."External Document No.")));
        GenJournalLine.Validate("Account Type", GenJournalLine."Account Type"::Customer);
        GenJournalLine.Validate("Account No.", Payment."Resolved Customer No.");
        GenJournalLine.Validate("Currency Code", Payment."Currency Code");
        GenJournalLine.Validate(Amount, -Abs(Payment.Amount));
        GenJournalLine.Validate("Bal. Account Type", GenJournalLine."Bal. Account Type"::"G/L Account");
        GenJournalLine.Validate("Bal. Account No.", Merchant."Clearing G/L Account No.");
        GenJournalLine."Adyen Payment ID" := Payment.SystemId;
        GenJournalLine.Insert(true);

        Payment."Status Before Manual" := Payment.Status;
        Payment.Status := Payment.Status::ManualJournalCreated;
        Payment."Manual Journal Template" := GenJournalLine."Journal Template Name";
        Payment."Manual Journal Batch" := GenJournalLine."Journal Batch Name";
        Payment."Manual Journal Line No." := GenJournalLine."Line No.";
        Payment.Modify(true);
    end;
}
