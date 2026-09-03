codeunit 72033 "Adyen Payment Poster"
{
    [CommitBehavior(CommitBehavior::Error)]
    procedure PostAndApply(var Payment: Record "Imported Adyen Payment")
    var
        Setup: Record "Adyen Setup";
        MatchedInvoice: Record "Cust. Ledger Entry";
        ExistingPaymentEntry: Record "Cust. Ledger Entry";
        GenJournalLine: Record "Gen. Journal Line" temporary;
        GenJournalPostLine: Codeunit "Gen. Jnl.-Post Line";
        NextLineNo: Integer;
    begin
        Setup.GetRecordOnce();
        Setup.ValidateForProcessing();
        Payment.TestField("Match Result", Payment."Match Result"::UniqueExact);
        Payment.TestField("Matched Invoice Entry No.");
        MatchedInvoice.Get(Payment."Matched Invoice Entry No.");

        ExistingPaymentEntry.SetRange("Customer No.", Payment."Resolved Customer No.");
        ExistingPaymentEntry.SetRange("Document Type", ExistingPaymentEntry."Document Type"::Payment);
        ExistingPaymentEntry.SetRange("Document No.", CopyStr(Payment."PSP Reference", 1, MaxStrLen(ExistingPaymentEntry."Document No.")));
        if ExistingPaymentEntry.FindFirst() then begin
            if Payment."Posted Payment Entry No." = ExistingPaymentEntry."Entry No." then
                exit;
            Error('A customer payment with PSP document number %1 already exists.', Payment."PSP Reference");
        end;

        GenJournalLine.SetRange("Journal Template Name", Setup."Journal Template Name");
        GenJournalLine.SetRange("Journal Batch Name", Setup."Journal Batch Name");
        if GenJournalLine.FindLast() then
            NextLineNo := GenJournalLine."Line No." + 10000
        else
            NextLineNo := 10000;

        GenJournalLine.Init();
        GenJournalLine.Validate("Journal Template Name", Setup."Journal Template Name");
        GenJournalLine.Validate("Journal Batch Name", Setup."Journal Batch Name");
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
        GenJournalLine.Validate("Bal. Account No.", Setup."Clearing G/L Account No.");
        GenJournalLine.Validate("Applies-to Doc. Type", GenJournalLine."Applies-to Doc. Type"::Invoice);
        GenJournalLine.Validate("Applies-to Doc. No.", MatchedInvoice."Document No.");
        GenJournalLine."Adyen Payment ID" := Payment.SystemId;
        GenJournalLine.Insert(true);

        GenJournalPostLine.RunWithCheck(GenJournalLine);

        MatchedInvoice.Get(Payment."Matched Invoice Entry No.");
        MatchedInvoice.CalcFields("Remaining Amount");
        if MatchedInvoice.Open or (MatchedInvoice."Remaining Amount" <> 0) then
            Error('The matched invoice was not fully applied by the payment posting.');

        ExistingPaymentEntry.Reset();
        ExistingPaymentEntry.SetCurrentKey("Customer No.", "Posting Date", "Currency Code");
        ExistingPaymentEntry.SetRange("Customer No.", Payment."Resolved Customer No.");
        ExistingPaymentEntry.SetRange("Document Type", ExistingPaymentEntry."Document Type"::Payment);
        ExistingPaymentEntry.SetRange("Document No.", CopyStr(Payment."PSP Reference", 1, MaxStrLen(ExistingPaymentEntry."Document No.")));
        if not ExistingPaymentEntry.FindLast() then
            Error('The posted customer payment could not be found after posting.');

        Payment."Posted Payment Entry No." := ExistingPaymentEntry."Entry No.";
        Payment.Status := Payment.Status::PostedApplied;
        Payment."Exception Message" := '';
        Payment.Modify(true);
    end;
}
