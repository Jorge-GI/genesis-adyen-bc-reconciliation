codeunit 72152 "Adyen Payment State Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure AdverseLifecycleRequiresFinanceReview()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        PaymentState: Codeunit "Adyen Payment State";
    begin
        ConfigureMerchants();
        AssertTrue(PaymentState.IsAdverseMessage('CAPTURE_FAILED'), 'Capture failures must be adverse.');
        AssertTrue(PaymentState.IsAdverseMessage('SECOND_CHARGEBACK'), 'Second chargebacks must be adverse.');
        AssertTrue(PaymentState.IsAdverseMessage('SETTLEMENT_REVERSED'), 'Settlement reversals must be adverse.');
        AssertFalse(PaymentState.IsAdverseMessage('AUTHORISATION'), 'Authorisation must not be adverse.');

        BuildEvent(EventEntry, 'MerchantA', 'REFUND', 'PSP-ADVERSE', 100, 20260903D, 'LOGICAL-ADVERSE');
        EventEntry."Original PSP Reference" := 'PSP-ADVERSE';
        PaymentState.ApplyAdverseEvent(EventEntry);
        Payment.Get('MerchantA', 'PSP-ADVERSE');
        AssertTrue(Payment.Status = Payment.Status::ReversalRequired, 'No adverse event may reverse accounting automatically.');
        AssertEqualInteger(0, Payment."Posted Payment Entry No.", 'An adverse event must not create a ledger entry.');
    end;

    [Test]
    procedure SamePspReferenceIsQualifiedByMerchant()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        PaymentState: Codeunit "Adyen Payment State";
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-SHARED', 100, 20260903D, 'LOGICAL-A');
        PaymentState.ImportPositivePayment(EventEntry, false);
        BuildEvent(EventEntry, 'MerchantB', 'AUTHORISATION', 'PSP-SHARED', 100, 20260903D, 'LOGICAL-B');
        PaymentState.ImportPositivePayment(EventEntry, false);

        Payment.SetRange("PSP Reference", 'PSP-SHARED');
        AssertEqualInteger(2, Payment.Count(), 'The imported payment identity must include merchant account.');
    end;

    [Test]
    procedure ReportBackfillUsesNormalPaymentPath()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        Reconciler: Codeunit "Adyen Report Reconciler";
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'SentForSettle', 'PSP-BACKFILL', 123.45, 20260903D, 'ROW-BACKFILL');
        EventEntry.Source := EventEntry.Source::Report;
        EventEntry."Original PSP Reference" := 'PSP-BACKFILL';
        Reconciler.ReconcileSentForSettle(EventEntry);

        Payment.Get('MerchantA', 'PSP-BACKFILL');
        AssertTrue(Payment.Backfilled, 'A report-only payment must be marked backfilled.');
        AssertTrue(Payment."Report Status" = Payment."Report Status"::Confirmed, 'A backfilled SentForSettle row must be confirmed.');
        AssertTrue(Payment.Status = Payment.Status::Imported, 'Auto Post must remain off unless explicitly enabled.');
    end;

    [Test]
    procedure ReportDifferenceDoesNotOverwritePayment()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        Reconciler: Codeunit "Adyen Report Reconciler";
    begin
        ConfigureMerchants();
        InsertPayment(Payment, 'MerchantA', 'PSP-DIFFERENT', 100, 'CUST-A');
        BuildEvent(EventEntry, 'MerchantA', 'SentForSettle', 'MOD-1', 101, 20260903D, 'ROW-DIFFERENT');
        EventEntry.Source := EventEntry.Source::Report;
        EventEntry."Original PSP Reference" := 'PSP-DIFFERENT';
        EventEntry."Shopper Reference" := 'CUST-B';
        Reconciler.ReconcileSentForSettle(EventEntry);

        Payment.Get('MerchantA', 'PSP-DIFFERENT');
        AssertTrue(Payment."Report Status" = Payment."Report Status"::Discrepancy, 'A report difference must be a discrepancy.');
        AssertEqualDecimal(100, Payment.Amount, 'The report must not overwrite authoritative payment amount.');
        AssertEqualText('CUST-A', Payment."Shopper Reference", 'The report must not overwrite authoritative customer data.');
    end;

    [Test]
    procedure ConflictingRetransmissionIsQuarantined()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        PaymentState: Codeunit "Adyen Payment State";
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-CONFLICT', 100, 20260903D, 'LOGICAL-FIRST');
        PaymentState.ImportPositivePayment(EventEntry, false);
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-CONFLICT', 101, 20260904D, 'LOGICAL-CONFLICT');
        PaymentState.ImportPositivePayment(EventEntry, false);

        Payment.Get('MerchantA', 'PSP-CONFLICT');
        AssertTrue(Payment.Status = Payment.Status::DataConflict, 'Conflicting data for one payment identity must be quarantined.');
        AssertEqualDecimal(100, Payment.Amount, 'Conflicting data must not overwrite the first authoritative payment.');
    end;

    [Test]
    procedure OutOfOrderAuthorisationCannotOverwriteNewerState()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        PaymentState: Codeunit "Adyen Payment State";
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-ORDER', 100, 20260904D, 'LOGICAL-NEW');
        PaymentState.ImportPositivePayment(EventEntry, false);
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-ORDER', 200, 20260903D, 'LOGICAL-OLD');
        PaymentState.ImportPositivePayment(EventEntry, false);

        Payment.Get('MerchantA', 'PSP-ORDER');
        AssertEqualDecimal(100, Payment.Amount, 'An older event must not overwrite a newer payment state.');
        AssertTrue(Payment.Status <> Payment.Status::DataConflict, 'An older event must be ignored, not treated as a new conflict.');
    end;

    [Test]
    procedure AutoPostDefaultsOffPerMerchant()
    var
        Merchant: Record "Adyen Merchant";
    begin
        Merchant.Init();
        Merchant."Merchant Account" := 'MerchantDefault';
        Merchant."Auto Post" := true;
        Merchant.Insert(true);
        AssertFalse(Merchant."Auto Post", 'New merchants must default Auto Post to off.');
    end;

    [Test]
    procedure FailedAuthorisationIsIgnoredWithoutPayment()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        EventWorker: Codeunit "Adyen Event Worker";
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-FAILED', 100, 20260903D, 'LOGICAL-FAILED');
        EventEntry."Transport ID" := 'TRANSPORT-FAILED';
        EventEntry.Success := false;
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);

        EventEntry.Get('TRANSPORT-FAILED');
        AssertTrue(EventEntry.Status = EventEntry.Status::Ignored, 'A failed authorisation must be ignored.');
        AssertFalse(Payment.Get('MerchantA', 'PSP-FAILED'), 'A failed authorisation must not create a payment.');
    end;

    local procedure ConfigureMerchants()
    var
        Merchant: Record "Adyen Merchant";
        MethodPolicy: Record "Adyen Payment Method Policy";
    begin
        MethodPolicy.DeleteAll(false);
        Merchant.DeleteAll(false);
        InsertMerchant(Merchant, 'MerchantA');
        InsertMerchant(Merchant, 'MerchantB');
    end;

    local procedure InsertMerchant(var Merchant: Record "Adyen Merchant"; MerchantAccount: Text)
    begin
        Merchant.Init();
        Merchant."Merchant Account" := MerchantAccount;
        Merchant.Enabled := true;
        Merchant.Insert(true);
    end;

    local procedure BuildEvent(var EventEntry: Record "Adyen Event Entry"; MerchantAccount: Text; MessageType: Text; PspReference: Text; Amount: Decimal; EventDate: Date; LogicalKey: Text)
    begin
        Clear(EventEntry);
        EventEntry.Init();
        EventEntry."Merchant Account" := MerchantAccount;
        EventEntry."Message Type" := MessageType;
        EventEntry."PSP Reference" := PspReference;
        EventEntry."Merchant Reference" := 'ORDER-1';
        EventEntry."Shopper Reference" := 'CUST-A';
        EventEntry."Payment Method" := 'scheme';
        EventEntry."Currency Code" := 'EUR';
        EventEntry.Amount := Amount;
        EventEntry."Occurred At UTC" := CreateDateTime(EventDate, 100000T);
        EventEntry."Logical Event Key" := LogicalKey;
        EventEntry."Success Provided" := true;
        EventEntry.Success := true;
    end;

    local procedure InsertPayment(var Payment: Record "Imported Adyen Payment"; MerchantAccount: Text; PspReference: Code[50]; Amount: Decimal; ShopperReference: Text)
    begin
        Payment.Init();
        Payment."Merchant Account" := MerchantAccount;
        Payment."PSP Reference" := PspReference;
        Payment."Merchant Reference" := 'ORDER-1';
        Payment."Shopper Reference" := ShopperReference;
        Payment."Payment Method" := 'scheme';
        Payment."Currency Code" := 'EUR';
        Payment.Amount := Amount;
        Payment."Event Date-Time" := CreateDateTime(20260903D, 100000T);
        Payment."Latest Event At UTC" := Payment."Event Date-Time";
        Payment."Origin Source" := Payment."Origin Source"::Webhook;
        Payment.Status := Payment.Status::Imported;
        Payment.Insert(true);
    end;

    local procedure AssertTrue(Actual: Boolean; FailureMessage: Text)
    begin
        if not Actual then
            Error(FailureMessage);
    end;

    local procedure AssertFalse(Actual: Boolean; FailureMessage: Text)
    begin
        if Actual then
            Error(FailureMessage);
    end;

    local procedure AssertEqualInteger(Expected: Integer; Actual: Integer; FailureMessage: Text)
    begin
        if Expected <> Actual then
            Error('%1 Expected %2, actual %3.', FailureMessage, Expected, Actual);
    end;

    local procedure AssertEqualDecimal(Expected: Decimal; Actual: Decimal; FailureMessage: Text)
    begin
        if Expected <> Actual then
            Error('%1 Expected %2, actual %3.', FailureMessage, Expected, Actual);
    end;

    local procedure AssertEqualText(Expected: Text; Actual: Text; FailureMessage: Text)
    begin
        if Expected <> Actual then
            Error('%1 Expected %2, actual %3.', FailureMessage, Expected, Actual);
    end;
}
