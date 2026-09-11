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
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigurePostingEnvironment(false);
        InvoiceEntryNo := PostInvoice('INV-AUTO', 100);
        BuildAuthorisation(EventEntry, 'PSP-AUTO', 100);
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);
        Payment.Get(MerchantAccount(), 'PSP-AUTO');
        AssertTrue(Payment.Status = Payment.Status::ReadyToPost, 'Auto Post off must retain an exact match for review.');
        AssertEqualInteger(0, Payment."Posted Payment Entry No.", 'Auto Post off must create no payment ledger entry.');

        Merchant.Get(MerchantAccount());
        Merchant."Auto Post" := true;
        Merchant.Modify(true);
        PaymentPoster.PostAndApplyAutomatically(Payment);
        Payment.Get(MerchantAccount(), 'PSP-AUTO');
        AssertTrue(Payment.Status = Payment.Status::PostedApplied, 'The exact match must post and apply when authorized.');
        AssertTrue(Payment."Posted Payment Entry No." <> 0, 'The customer payment ledger entry must be linked.');
        AssertTrue(Payment."Posting Origin" = Payment."Posting Origin"::Automatic, 'The automatic posting path must record the automatic origin.');
        CustLedgerEntry.Get(InvoiceEntryNo);
        CustLedgerEntry.CalcFields("Remaining Amount");
        AssertTrue(not CustLedgerEntry.Open and (CustLedgerEntry."Remaining Amount" = 0), 'The invoice must be fully applied.');

        PaymentCount := CountPaymentEntries('PSP-AUTO');
        PaymentPoster.PostAndApplyAutomatically(Payment);
        AssertEqualInteger(PaymentCount, CountPaymentEntries('PSP-AUTO'), 'A linked payment must not post twice.');
    end;

    [Test]
    procedure PaymentStateAutoPostRecordsAutomaticOrigin()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        PaymentState: Codeunit "Adyen Payment State";
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigurePostingEnvironment(true);
        PostInvoice('INV-STATE-AUTO', 100);
        BuildAuthorisation(EventEntry, 'PSP-STATE-AUTO', 100);

        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);

        Payment.Get(MerchantAccount(), 'PSP-STATE-AUTO');
        AssertTrue(Payment.Status = Payment.Status::PostedApplied, 'The payment-state auto-post path must post an exact match.');
        AssertTrue(Payment."Posted Payment Entry No." <> 0, 'The payment-state auto-post path must link the customer ledger entry.');
        AssertTrue(Payment."Posting Origin" = Payment."Posting Origin"::Automatic, 'The payment-state auto-post path must record the automatic origin.');
    end;

    [Test]
    procedure CancellationAfterPostingRequiresReviewWithoutLedgerMutation()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        PaymentState: Codeunit "Adyen Payment State";
        PaymentPoster: Codeunit "Adyen Payment Poster";
        PaymentCount: Integer;
        PostedPaymentEntryNo: Integer;
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigurePostingEnvironment(false);
        PostInvoice('INV-CANCEL', 100);
        BuildAuthorisation(EventEntry, 'PSP-CANCEL', 100);
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);
        Payment.Get(MerchantAccount(), 'PSP-CANCEL');
        PaymentPoster.PostAndApplyAutomatically(Payment);
        Payment.Get(MerchantAccount(), 'PSP-CANCEL');
        PostedPaymentEntryNo := Payment."Posted Payment Entry No.";
        PaymentCount := CountPaymentEntries('PSP-CANCEL');

        BuildAuthorisation(EventEntry, 'MOD-CANCEL', 100);
        EventEntry."Message Type" := 'CANCELLATION';
        EventEntry."Original PSP Reference" := 'PSP-CANCEL';
        EventEntry."Occurred At UTC" := CreateDateTime(WorkDate(), 110000T);
        EventEntry."Logical Event Key" := 'LOGICAL-CANCEL-AFTER-POST';
        PaymentState.ApplyAdverseEventWithResult(EventEntry, DispositionReason, LifecycleApplied);

        Payment.Get(MerchantAccount(), 'PSP-CANCEL');
        AssertTrue(Payment.Status = Payment.Status::ReversalRequired, 'A cancellation after posting must require finance review.');
        AssertEqualInteger(PostedPaymentEntryNo, Payment."Posted Payment Entry No.", 'The cancellation must retain the posted customer ledger link.');
        AssertEqualInteger(PaymentCount, CountPaymentEntries('PSP-CANCEL'), 'The cancellation must not create or reverse customer ledger entries automatically.');
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
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigurePostingEnvironment(false);
        PostInvoice('INV-CLOSED', 100);
        BuildAuthorisation(EventEntry, 'PSP-CLOSED', 100);
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);
        Payment.Get(MerchantAccount(), 'PSP-CLOSED');

        GeneralLedgerSetup.Get();
        OriginalAllowFrom := GeneralLedgerSetup."Allow Posting From";
        OriginalAllowTo := GeneralLedgerSetup."Allow Posting To";
        GeneralLedgerSetup."Allow Posting From" := CalcDate('<+1D>', WorkDate());
        GeneralLedgerSetup."Allow Posting To" := 0D;
        GeneralLedgerSetup.Modify(false);
        asserterror PaymentPoster.PostAndApplyAutomatically(Payment);
        AssertEqualInteger(0, CountPaymentEntries('PSP-CLOSED'), 'A closed-period failure must leave no partial payment entry.');
        Payment.Get(MerchantAccount(), 'PSP-CLOSED');
        AssertEqualInteger(0, Payment."Posted Payment Entry No.", 'A failed posting must not link a customer ledger entry.');
        AssertTrue(Payment."Posting Origin" = Payment."Posting Origin"::Unclassified, 'A failed posting must not classify the payment origin.');

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
        AssertTrue(GenJournalLine."Adyen Posting Origin" = GenJournalLine."Adyen Posting Origin"::ManualJournal, 'A manual draft must carry the manual journal origin.');

        GenJournalLine.Delete(true);
        Payment.Get(MerchantAccount(), 'PSP-MANUAL-DELETE');
        AssertTrue(Payment.Status = Payment.Status::Imported, 'Deleting the draft must restore the prior payment state.');
        AssertEqualInteger(0, Payment."Manual Journal Line No.", 'Deleting the draft must clear the journal link.');
        AssertTrue(Payment."Posting Origin" = Payment."Posting Origin"::Unclassified, 'Deleting an unposted draft must not classify the payment origin.');
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
        AssertTrue(Payment."Posting Origin" = Payment."Posting Origin"::ManualJournal, 'Posting a manual draft must record the manual journal origin.');
    end;

    [Test]
    procedure PreviewingManualDraftDoesNotSetPostingOrigin()
    var
        GenJournalLine: Record "Gen. Journal Line";
        Payment: Record "Imported Adyen Payment";
        GenJnlPost: Codeunit "Gen. Jnl.-Post";
        GenJnlPostPreview: Codeunit "Gen. Jnl.-Post Preview";
        ManualJournal: Codeunit "Adyen Manual Journal";
    begin
        ConfigurePostingEnvironment(false);
        InsertManualPayment(Payment, 'PSP-MANUAL-PREVIEW');
        ManualJournal.CreateDraft(Payment, GenJournalLine);
        GenJnlPostPreview.SetContext(GenJnlPost, GenJournalLine);

        asserterror GenJnlPostPreview.Run();

        Payment.Get(MerchantAccount(), 'PSP-MANUAL-PREVIEW');
        AssertTrue(Payment.Status = Payment.Status::ManualJournalCreated, 'Posting preview must retain the manual-draft state.');
        AssertEqualInteger(0, Payment."Posted Payment Entry No.", 'Posting preview must not link a customer ledger entry.');
        AssertTrue(Payment."Posting Origin" = Payment."Posting Origin"::Unclassified, 'Posting preview must not classify the payment origin.');
    end;

    [Test]
    procedure ManualExactMatchRecordsOrigin()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        PaymentPoster: Codeunit "Adyen Payment Poster";
        PaymentState: Codeunit "Adyen Payment State";
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigurePostingEnvironment(false);
        PostInvoice('INV-MANUAL-EXACT', 100);
        BuildAuthorisation(EventEntry, 'PSP-MANUAL-EXACT', 100);
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);
        Payment.Get(MerchantAccount(), 'PSP-MANUAL-EXACT');

        PaymentPoster.PostAndApplyManualExactMatch(Payment);

        Payment.Get(MerchantAccount(), 'PSP-MANUAL-EXACT');
        AssertTrue(Payment."Posted Payment Entry No." <> 0, 'Manual exact-match posting must link the customer ledger entry.');
        AssertTrue(Payment."Posting Origin" = Payment."Posting Origin"::ManualExactMatch, 'Manual exact-match posting must record the manual exact-match origin.');
    end;

    local procedure ConfigurePostingEnvironment(AutoPost: Boolean)
    var
        Customer: Record Customer;
        CustomerPostingGroup: Record "Customer Posting Group";
        GenJournalBatch: Record "Gen. Journal Batch";
        GenJournalTemplate: Record "Gen. Journal Template";
        GLAccount: Record "G/L Account";
        Merchant: Record "Adyen Merchant";
        MethodPolicy: Record "Adyen Merchant Method Policy";
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
        MethodPolicy."Merchant Account" := MerchantAccount();
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
