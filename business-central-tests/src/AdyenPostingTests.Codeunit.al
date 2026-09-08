codeunit 72157 "Adyen Posting Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure AutoPostOffThenOnPostsAndAppliesOnce()
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
        EventEntry: Record "Adyen Event Entry";
        Merchant: Record "Adyen Merchant";
        Payment: Record "Imported Adyen Payment";
        PaymentState: Codeunit "Adyen Payment State";
        PaymentPoster: Codeunit "Adyen Payment Poster";
        InvoiceEntryNo: Integer;
        PaymentCount: Integer;
    begin
        ConfigurePostingEnvironment(false);
        InvoiceEntryNo := PostInvoice('INV-AUTO', 100);
        BuildAuthorisation(EventEntry, 'PSP-AUTO', 100);
        PaymentState.ImportPositivePayment(EventEntry, false);
        Payment.Get(MerchantAccount(), 'PSP-AUTO');
        AssertTrue(Payment.Status = Payment.Status::ReadyToPost, 'Auto Post off must retain an exact match for review.');
        AssertEqualInteger(0, Payment."Posted Payment Entry No.", 'Auto Post off must create no payment ledger entry.');

        Merchant.Get(MerchantAccount());
        Merchant."Auto Post" := true;
        Merchant.Modify(true);
        PaymentPoster.PostAndApply(Payment);
        Payment.Get(MerchantAccount(), 'PSP-AUTO');
        AssertTrue(Payment.Status = Payment.Status::PostedApplied, 'The exact match must post and apply when authorized.');
        AssertTrue(Payment."Posted Payment Entry No." <> 0, 'The customer payment ledger entry must be linked.');
        CustLedgerEntry.Get(InvoiceEntryNo);
        CustLedgerEntry.CalcFields("Remaining Amount");
        AssertTrue(not CustLedgerEntry.Open and (CustLedgerEntry."Remaining Amount" = 0), 'The invoice must be fully applied.');

        PaymentCount := CountPaymentEntries('PSP-AUTO');
        PaymentPoster.PostAndApply(Payment);
        AssertEqualInteger(PaymentCount, CountPaymentEntries('PSP-AUTO'), 'A linked payment must not post twice.');
    end;

    [Test]
    procedure ClosedPeriodFailureLeavesNoPartialPayment()
    var
        EventEntry: Record "Adyen Event Entry";
        GeneralLedgerSetup: Record "General Ledger Setup";
        Payment: Record "Imported Adyen Payment";
        PaymentState: Codeunit "Adyen Payment State";
        PaymentPoster: Codeunit "Adyen Payment Poster";
        OriginalAllowFrom: Date;
        OriginalAllowTo: Date;
    begin
        ConfigurePostingEnvironment(false);
        PostInvoice('INV-CLOSED', 100);
        BuildAuthorisation(EventEntry, 'PSP-CLOSED', 100);
        PaymentState.ImportPositivePayment(EventEntry, false);
        Payment.Get(MerchantAccount(), 'PSP-CLOSED');

        GeneralLedgerSetup.Get();
        OriginalAllowFrom := GeneralLedgerSetup."Allow Posting From";
        OriginalAllowTo := GeneralLedgerSetup."Allow Posting To";
        GeneralLedgerSetup."Allow Posting From" := CalcDate('<+1D>', WorkDate());
        GeneralLedgerSetup."Allow Posting To" := 0D;
        GeneralLedgerSetup.Modify(false);
        asserterror PaymentPoster.PostAndApply(Payment);
        AssertEqualInteger(0, CountPaymentEntries('PSP-CLOSED'), 'A closed-period failure must leave no partial payment entry.');

        GeneralLedgerSetup."Allow Posting From" := OriginalAllowFrom;
        GeneralLedgerSetup."Allow Posting To" := OriginalAllowTo;
        GeneralLedgerSetup.Modify(false);
    end;

    [Test]
    procedure ManualDraftIsUniqueAndDeletionResetsState()
    var
        GenJournalLine: Record "Gen. Journal Line";
        SecondGenJournalLine: Record "Gen. Journal Line";
        Payment: Record "Imported Adyen Payment";
        ManualJournal: Codeunit "Adyen Manual Journal";
    begin
        ConfigurePostingEnvironment(false);
        InsertManualPayment(Payment, 'PSP-MANUAL-DELETE');
        ManualJournal.CreateDraft(Payment, GenJournalLine);
        ManualJournal.CreateDraft(Payment, SecondGenJournalLine);
        AssertTrue(GenJournalLine."Line No." = SecondGenJournalLine."Line No.", 'Creating a draft twice must return the same journal line.');
        AssertEqualInteger(1, CountLinkedJournalLines(Payment.SystemId), 'Only one linked manual journal line may exist.');

        GenJournalLine.Delete(true);
        Payment.Get(MerchantAccount(), 'PSP-MANUAL-DELETE');
        AssertTrue(Payment.Status = Payment.Status::Imported, 'Deleting the draft must restore the prior payment state.');
        AssertEqualInteger(0, Payment."Manual Journal Line No.", 'Deleting the draft must clear the journal link.');
    end;

    [Test]
    procedure PostedManualDraftRecordsCustomerLedgerEntry()
    var
        GenJournalLine: Record "Gen. Journal Line";
        Payment: Record "Imported Adyen Payment";
        GenJournalPostLine: Codeunit "Gen. Jnl.-Post Line";
        ManualJournal: Codeunit "Adyen Manual Journal";
    begin
        ConfigurePostingEnvironment(false);
        InsertManualPayment(Payment, 'PSP-MANUAL-POST');
        ManualJournal.CreateDraft(Payment, GenJournalLine);
        GenJournalPostLine.RunWithCheck(GenJournalLine);

        Payment.Get(MerchantAccount(), 'PSP-MANUAL-POST');
        AssertTrue(Payment.Status = Payment.Status::ManuallyReconciled, 'Posting a manual draft must update its payment state.');
        AssertTrue(Payment."Posted Payment Entry No." <> 0, 'Posting a manual draft must retain its customer ledger entry.');
    end;

    local procedure ConfigurePostingEnvironment(AutoPost: Boolean)
    var
        Customer: Record Customer;
        CustomerPostingGroup: Record "Customer Posting Group";
        GenJournalBatch: Record "Gen. Journal Batch";
        GenJournalTemplate: Record "Gen. Journal Template";
        GLAccount: Record "G/L Account";
        Merchant: Record "Adyen Merchant";
        MethodPolicy: Record "Adyen Payment Method Policy";
        SourceCode: Record "Source Code";
    begin
        InsertPostingAccount(GLAccount, ReceivablesAccount());
        InsertPostingAccount(GLAccount, RevenueAccount());
        InsertPostingAccount(GLAccount, ClearingAccount());

        CustomerPostingGroup.Init();
        CustomerPostingGroup.Code := CustomerPostingGroupCode();
        CustomerPostingGroup."Receivables Account" := ReceivablesAccount();
        CustomerPostingGroup.Insert(false);

        Customer.Init();
        Customer."No." := CustomerNo();
        Customer.Name := 'Adyen posting test customer';
        Customer."Customer Posting Group" := CustomerPostingGroupCode();
        Customer.Insert(false);

        SourceCode.Init();
        SourceCode.Code := 'ADYTEST';
        SourceCode.Description := 'Adyen tests';
        SourceCode.Insert(false);

        GenJournalTemplate.Init();
        GenJournalTemplate.Name := JournalTemplateName();
        GenJournalTemplate.Description := 'Adyen tests';
        GenJournalTemplate.Type := GenJournalTemplate.Type::Payments;
        GenJournalTemplate."Source Code" := SourceCode.Code;
        GenJournalTemplate.Insert(false);
        InsertJournalBatch(GenJournalBatch, AutoBatchName());
        InsertJournalBatch(GenJournalBatch, ManualBatchName());

        Merchant.Init();
        Merchant."Merchant Account" := MerchantAccount();
        Merchant.Enabled := true;
        Merchant."Journal Template Name" := JournalTemplateName();
        Merchant."Journal Batch Name" := AutoBatchName();
        Merchant."Manual Journal Batch Name" := ManualBatchName();
        Merchant."Clearing G/L Account No." := ClearingAccount();
        Merchant.Insert(true);
        Merchant."Auto Post" := AutoPost;
        Merchant.Modify(true);

        MethodPolicy.Init();
        MethodPolicy."Payment Method" := 'scheme';
        MethodPolicy."Enabled for Auto Post" := true;
        MethodPolicy.Insert(true);
    end;

    local procedure InsertPostingAccount(var GLAccount: Record "G/L Account"; AccountNo: Code[20])
    begin
        GLAccount.Init();
        GLAccount."No." := AccountNo;
        GLAccount.Name := AccountNo;
        GLAccount."Account Type" := GLAccount."Account Type"::Posting;
        GLAccount."Direct Posting" := true;
        GLAccount.Insert(false);
    end;

    local procedure InsertJournalBatch(var GenJournalBatch: Record "Gen. Journal Batch"; BatchName: Code[10])
    begin
        GenJournalBatch.Init();
        GenJournalBatch."Journal Template Name" := JournalTemplateName();
        GenJournalBatch.Name := BatchName;
        GenJournalBatch.Description := BatchName;
        GenJournalBatch.Insert(false);
    end;

    local procedure PostInvoice(DocumentNo: Code[20]; Amount: Decimal): Integer
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
        GenJournalLine: Record "Gen. Journal Line" temporary;
        GenJournalPostLine: Codeunit "Gen. Jnl.-Post Line";
    begin
        GenJournalLine.Init();
        GenJournalLine.Validate("Journal Template Name", JournalTemplateName());
        GenJournalLine.Validate("Journal Batch Name", AutoBatchName());
        GenJournalLine."Line No." := 10000;
        GenJournalLine.Validate("Posting Date", WorkDate());
        GenJournalLine.Validate("Document Type", GenJournalLine."Document Type"::Invoice);
        GenJournalLine.Validate("Document No.", DocumentNo);
        GenJournalLine.Validate("Account Type", GenJournalLine."Account Type"::Customer);
        GenJournalLine.Validate("Account No.", CustomerNo());
        GenJournalLine.Validate(Amount, Amount);
        GenJournalLine.Validate("Bal. Account Type", GenJournalLine."Bal. Account Type"::"G/L Account");
        GenJournalLine.Validate("Bal. Account No.", RevenueAccount());
        GenJournalLine.Insert(true);
        GenJournalPostLine.RunWithCheck(GenJournalLine);

        CustLedgerEntry.SetRange("Customer No.", CustomerNo());
        CustLedgerEntry.SetRange("Document Type", CustLedgerEntry."Document Type"::Invoice);
        CustLedgerEntry.SetRange("Document No.", DocumentNo);
        CustLedgerEntry.FindLast();
        exit(CustLedgerEntry."Entry No.");
    end;

    local procedure BuildAuthorisation(var EventEntry: Record "Adyen Event Entry"; PspReference: Text; Amount: Decimal)
    begin
        Clear(EventEntry);
        EventEntry.Init();
        EventEntry.Source := EventEntry.Source::Webhook;
        EventEntry."Merchant Account" := MerchantAccount();
        EventEntry."Message Type" := 'AUTHORISATION';
        EventEntry."PSP Reference" := PspReference;
        EventEntry."Merchant Reference" := 'ORDER-POST';
        EventEntry."Shopper Reference" := CustomerNo();
        EventEntry."Payment Method" := 'scheme';
        EventEntry.Amount := Amount;
        EventEntry."Occurred At UTC" := CreateDateTime(WorkDate(), 100000T);
        EventEntry."Logical Event Key" := CopyStr('LOGICAL-' + PspReference, 1, 64);
        EventEntry."Success Provided" := true;
        EventEntry.Success := true;
    end;

    local procedure InsertManualPayment(var Payment: Record "Imported Adyen Payment"; PspReference: Code[50])
    begin
        Payment.Init();
        Payment."Merchant Account" := MerchantAccount();
        Payment."PSP Reference" := PspReference;
        Payment."Shopper Reference" := CustomerNo();
        Payment."Resolved Customer No." := CustomerNo();
        Payment."Payment Method" := 'scheme';
        Payment.Amount := 50;
        Payment."Event Date-Time" := CreateDateTime(WorkDate(), 100000T);
        Payment.Status := Payment.Status::Imported;
        Payment.Insert(true);
    end;

    local procedure CountPaymentEntries(DocumentNo: Code[20]): Integer
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
    begin
        CustLedgerEntry.SetRange("Customer No.", CustomerNo());
        CustLedgerEntry.SetRange("Document Type", CustLedgerEntry."Document Type"::Payment);
        CustLedgerEntry.SetRange("Document No.", DocumentNo);
        exit(CustLedgerEntry.Count());
    end;

    local procedure CountLinkedJournalLines(PaymentId: Guid): Integer
    var
        GenJournalLine: Record "Gen. Journal Line";
    begin
        GenJournalLine.SetRange("Adyen Payment ID", PaymentId);
        exit(GenJournalLine.Count());
    end;

    local procedure MerchantAccount(): Text
    begin
        exit('PostingMerchant');
    end;

    local procedure CustomerNo(): Code[20]
    begin
        exit('ADY-POST');
    end;

    local procedure CustomerPostingGroupCode(): Code[20]
    begin
        exit('ADYPOST');
    end;

    local procedure ReceivablesAccount(): Code[20]
    begin
        exit('ADYREC');
    end;

    local procedure RevenueAccount(): Code[20]
    begin
        exit('ADYREV');
    end;

    local procedure ClearingAccount(): Code[20]
    begin
        exit('ADYCLR');
    end;

    local procedure JournalTemplateName(): Code[10]
    begin
        exit('ADYTEST');
    end;

    local procedure AutoBatchName(): Code[10]
    begin
        exit('AUTO');
    end;

    local procedure ManualBatchName(): Code[10]
    begin
        exit('MANUAL');
    end;

    local procedure AssertTrue(Actual: Boolean; FailureMessage: Text)
    begin
        if not Actual then
            Error(FailureMessage);
    end;

    local procedure AssertEqualInteger(Expected: Integer; Actual: Integer; FailureMessage: Text)
    begin
        if Expected <> Actual then
            Error('%1 Expected %2, actual %3.', FailureMessage, Expected, Actual);
    end;
}
