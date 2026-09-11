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
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigureMerchants();
        AssertTrue(PaymentState.IsAdverseMessage('CAPTURE_FAILED'), 'Capture failures must be adverse.');
        AssertTrue(PaymentState.IsAdverseMessage('Cancelled'), 'Cancelled report rows must be adverse.');
        AssertTrue(PaymentState.IsAdverseMessage('CANCELLATION'), 'Cancellation webhooks must be adverse.');
        AssertTrue(PaymentState.IsAdverseMessage('Expired'), 'Expired report rows must be adverse.');
        AssertTrue(PaymentState.IsAdverseMessage('EXPIRE'), 'Expire webhooks must be adverse.');
        AssertTrue(PaymentState.IsAdverseMessage('SECOND_CHARGEBACK'), 'Second chargebacks must be adverse.');
        AssertTrue(PaymentState.IsAdverseMessage('SETTLEMENT_REVERSED'), 'Settlement reversals must be adverse.');
        AssertFalse(PaymentState.IsAdverseMessage('AUTHORISATION'), 'Authorisation must not be adverse.');
        AssertFalse(PaymentState.IsAdverseMessage('REFUND'), 'Refund initiation is audit-only until PAR confirms Refunded.');
        AssertFalse(PaymentState.IsAdverseMessage('CANCEL_OR_REFUND'), 'Cancel-or-refund webhooks remain outside the supported direct-event scope.');
        AssertFalse(PaymentState.IsAdverseMessage('TECHNICAL_CANCEL'), 'Technical-cancel webhooks remain outside the supported direct-event scope.');

        BuildEvent(EventEntry, 'MerchantA', 'CAPTURE_FAILED', 'PSP-ADVERSE', 100, 20260903D, 'LOGICAL-ADVERSE');
        EventEntry."Original PSP Reference" := 'PSP-ADVERSE';
        PaymentState.ApplyAdverseEventWithResult(EventEntry, DispositionReason, LifecycleApplied);
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
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-SHARED', 100, 20260903D, 'LOGICAL-A');
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);
        BuildEvent(EventEntry, 'MerchantB', 'AUTHORISATION', 'PSP-SHARED', 100, 20260903D, 'LOGICAL-B');
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);

        Payment.SetRange("PSP Reference", 'PSP-SHARED');
        AssertEqualInteger(2, Payment.Count(), 'The imported payment identity must include merchant account.');
    end;

    [Test]
    procedure AuthorisedSentForSettleAndSettledProgressOnePayment()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        PaymentState: Codeunit "Adyen Payment State";
        Reconciler: Codeunit "Adyen Report Reconciler";
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-LIFECYCLE', 100, 20260901D, 'LIFECYCLE-AUTH');
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);
        Payment.Get('MerchantA', 'PSP-LIFECYCLE');
        AssertTrue(Payment."Adyen Lifecycle Status" = Payment."Adyen Lifecycle Status"::Authorised, 'A successful authorisation must start the tracked lifecycle.');

        BuildEvent(EventEntry, 'MerchantA', 'SentForSettle', 'PSP-LIFECYCLE', 100, 20260902D, 'LIFECYCLE-SENT');
        EventEntry.Source := EventEntry.Source::Report;
        EventEntry."Original PSP Reference" := 'PSP-LIFECYCLE';
        Reconciler.ReconcilePositiveLifecycleWithResult(EventEntry, DispositionReason, LifecycleApplied);
        Payment.Get('MerchantA', 'PSP-LIFECYCLE');
        AssertTrue(Payment."Adyen Lifecycle Status" = Payment."Adyen Lifecycle Status"::SentForSettle, 'SentForSettle must be retained as a normal-flow milestone.');

        BuildEvent(EventEntry, 'MerchantA', 'Settled', 'PSP-LIFECYCLE', 100, 20260903D, 'LIFECYCLE-SETTLED');
        EventEntry.Source := EventEntry.Source::Report;
        EventEntry."Original PSP Reference" := 'PSP-LIFECYCLE';
        Reconciler.ReconcilePositiveLifecycleWithResult(EventEntry, DispositionReason, LifecycleApplied);
        Payment.Get('MerchantA', 'PSP-LIFECYCLE');
        AssertTrue(Payment."Adyen Lifecycle Status" = Payment."Adyen Lifecycle Status"::Settled, 'Settled must record positive completion.');
        Payment.SetRange("Merchant Account", 'MerchantA');
        Payment.SetRange("PSP Reference", 'PSP-LIFECYCLE');
        AssertEqualInteger(1, Payment.Count(), 'All normal milestones must resolve to one imported payment.');
    end;

    [Test]
    procedure AuthorisedAndSettledReportRowsCanBackfillMissingPayments()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        Reconciler: Codeunit "Adyen Report Reconciler";
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'Authorised', 'PSP-REPORT-AUTH', 75, 20260901D, 'REPORT-AUTH');
        EventEntry.Source := EventEntry.Source::Report;
        EventEntry."Original PSP Reference" := 'PSP-REPORT-AUTH';
        Reconciler.ReconcilePositiveLifecycleWithResult(EventEntry, DispositionReason, LifecycleApplied);
        Payment.Get('MerchantA', 'PSP-REPORT-AUTH');
        AssertTrue(Payment.Backfilled, 'A report Authorised row must backfill a missing payment.');
        AssertTrue(Payment."Adyen Lifecycle Status" = Payment."Adyen Lifecycle Status"::Authorised, 'A report Authorised row must expose Authorised lifecycle.');

        BuildEvent(EventEntry, 'MerchantA', 'Settled', 'PSP-REPORT-SETTLED', 80, 20260903D, 'REPORT-SETTLED');
        EventEntry.Source := EventEntry.Source::Report;
        EventEntry."Original PSP Reference" := 'PSP-REPORT-SETTLED';
        Reconciler.ReconcilePositiveLifecycleWithResult(EventEntry, DispositionReason, LifecycleApplied);
        Payment.Get('MerchantA', 'PSP-REPORT-SETTLED');
        AssertTrue(Payment.Backfilled, 'A report Settled row must backfill a missing payment.');
        AssertTrue(Payment."Adyen Lifecycle Status" = Payment."Adyen Lifecycle Status"::Settled, 'A report Settled row must expose Settled lifecycle.');
    end;

    [Test]
    procedure UnsupportedIntermediateWebhooksAreAuditedWithoutChangingPayment()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        EventWorker: Codeunit "Adyen Event Worker";
        PaymentState: Codeunit "Adyen Payment State";
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-REFUND-AUDIT', 100, 20260901D, 'REFUND-AUTH');
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);

        BuildEvent(EventEntry, 'MerchantA', 'REFUND', 'MOD-REFUND-AUDIT', 100, 20260902D, 'REFUND-INITIATED');
        EventEntry."Original PSP Reference" := 'PSP-REFUND-AUDIT';
        EventEntry."Transport ID" := 'TRANSPORT-REFUND-AUDIT';
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);

        EventEntry.Get('TRANSPORT-REFUND-AUDIT');
        AssertTrue(EventEntry.Status = EventEntry.Status::Ignored, 'REFUND must remain in the audit trail as intentionally unsupported.');

        BuildEvent(EventEntry, 'MerchantA', 'CANCEL_OR_REFUND', 'MOD-CANCEL-OR-REFUND', 100, 20260902D, 'CANCEL-OR-REFUND');
        EventEntry."Original PSP Reference" := 'PSP-REFUND-AUDIT';
        EventEntry."Transport ID" := 'TRANSPORT-CANCEL-OR-REFUND';
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);
        EventEntry.Get('TRANSPORT-CANCEL-OR-REFUND');
        AssertTrue(EventEntry.Status = EventEntry.Status::Ignored, 'CANCEL_OR_REFUND must remain in the audit trail as intentionally unsupported.');

        BuildEvent(EventEntry, 'MerchantA', 'TECHNICAL_CANCEL', 'MOD-TECHNICAL-CANCEL', 100, 20260902D, 'TECHNICAL-CANCEL');
        EventEntry."Original PSP Reference" := 'PSP-REFUND-AUDIT';
        EventEntry."Transport ID" := 'TRANSPORT-TECHNICAL-CANCEL';
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);
        EventEntry.Get('TRANSPORT-TECHNICAL-CANCEL');
        AssertTrue(EventEntry.Status = EventEntry.Status::Ignored, 'TECHNICAL_CANCEL must remain in the audit trail as intentionally unsupported.');

        Payment.Get('MerchantA', 'PSP-REFUND-AUDIT');
        AssertTrue(Payment.Status <> Payment.Status::ReversalRequired, 'Unsupported intermediates must not trigger finance review.');
        AssertTrue(Payment."Adyen Lifecycle Status" = Payment."Adyen Lifecycle Status"::Authorised, 'Unsupported intermediates must not change the displayed lifecycle.');
    end;

    [Test]
    procedure SettlementRecoveryUpdatesLifecycleButKeepsFinanceReview()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        PaymentState: Codeunit "Adyen Payment State";
        Reconciler: Codeunit "Adyen Report Reconciler";
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-RECOVERY', 100, 20260901D, 'RECOVERY-AUTH');
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);
        BuildEvent(EventEntry, 'MerchantA', 'SETTLED_REVERSED', 'PSP-RECOVERY', 100, 20260902D, 'RECOVERY-REVERSED');
        EventEntry."Original PSP Reference" := 'PSP-RECOVERY';
        PaymentState.ApplyAdverseEventWithResult(EventEntry, DispositionReason, LifecycleApplied);

        BuildEvent(EventEntry, 'MerchantA', 'Settled', 'PSP-RECOVERY', 101, 20260903D, 'RECOVERY-SETTLED');
        EventEntry.Source := EventEntry.Source::Report;
        EventEntry."Original PSP Reference" := 'PSP-RECOVERY';
        Reconciler.ReconcilePositiveLifecycleWithResult(EventEntry, DispositionReason, LifecycleApplied);

        Payment.Get('MerchantA', 'PSP-RECOVERY');
        AssertTrue(Payment."Adyen Lifecycle Status" = Payment."Adyen Lifecycle Status"::Settled, 'A later settlement recovery must update the lifecycle.');
        AssertTrue(Payment.Status = Payment.Status::ReversalRequired, 'Lifecycle recovery must not automatically clear finance review.');
        AssertEqualDecimal(100, Payment.Amount, 'Reversal Required must take precedence over a later report data mismatch.');
    end;

    [Test]
    procedure SupportedEventNamesMapToLifecycleValues()
    var
        PaymentState: Codeunit "Adyen Payment State";
    begin
        AssertLifecycleMapping(PaymentState, 'AUTHORISATION', Enum::"Adyen Lifecycle Status"::Authorised);
        AssertLifecycleMapping(PaymentState, 'SentForSettle', Enum::"Adyen Lifecycle Status"::SentForSettle);
        AssertLifecycleMapping(PaymentState, 'Settled', Enum::"Adyen Lifecycle Status"::Settled);
        AssertLifecycleMapping(PaymentState, 'CANCELLATION', Enum::"Adyen Lifecycle Status"::Cancelled);
        AssertLifecycleMapping(PaymentState, 'EXPIRE', Enum::"Adyen Lifecycle Status"::Expired);
        AssertLifecycleMapping(PaymentState, 'CaptureFailed', Enum::"Adyen Lifecycle Status"::CaptureFailed);
        AssertLifecycleMapping(PaymentState, 'Refunded', Enum::"Adyen Lifecycle Status"::Refunded);
        AssertLifecycleMapping(PaymentState, 'RefundFailed', Enum::"Adyen Lifecycle Status"::RefundFailed);
        AssertLifecycleMapping(PaymentState, 'RefundedReversed', Enum::"Adyen Lifecycle Status"::RefundedReversed);
        AssertLifecycleMapping(PaymentState, 'Chargeback', Enum::"Adyen Lifecycle Status"::Chargeback);
        AssertLifecycleMapping(PaymentState, 'ChargebackReversed', Enum::"Adyen Lifecycle Status"::ChargebackReversed);
        AssertLifecycleMapping(PaymentState, 'SecondChargeback', Enum::"Adyen Lifecycle Status"::SecondChargeback);
        AssertLifecycleMapping(PaymentState, 'SettledReversed', Enum::"Adyen Lifecycle Status"::SettledReversed);
    end;

    [Test]
    procedure ReportBackfillUsesNormalPaymentPath()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        Reconciler: Codeunit "Adyen Report Reconciler";
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'SentForSettle', 'PSP-BACKFILL', 123.45, 20260903D, 'ROW-BACKFILL');
        EventEntry.Source := EventEntry.Source::Report;
        EventEntry."Original PSP Reference" := 'PSP-BACKFILL';
        Reconciler.ReconcilePositiveLifecycleWithResult(EventEntry, DispositionReason, LifecycleApplied);

        Payment.Get('MerchantA', 'PSP-BACKFILL');
        AssertTrue(Payment.Backfilled, 'A report-only payment must be marked backfilled.');
        AssertTrue(Payment."Adyen Lifecycle Status" = Payment."Adyen Lifecycle Status"::SentForSettle, 'The report milestone must set the lifecycle status.');
        AssertTrue(Payment.Status = Payment.Status::Imported, 'Auto Post must remain off unless explicitly enabled.');
    end;

    [Test]
    procedure ReportDifferenceDoesNotOverwritePayment()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        Reconciler: Codeunit "Adyen Report Reconciler";
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigureMerchants();
        InsertPayment(Payment, 'MerchantA', 'PSP-DIFFERENT', 100, 'CUST-A');
        Payment.Status := Payment.Status::PostedApplied;
        Payment."Posted Payment Entry No." := 700001;
        Payment.Modify(true);
        BuildEvent(EventEntry, 'MerchantA', 'SentForSettle', 'MOD-1', 101, 20260903D, 'ROW-DIFFERENT');
        EventEntry.Source := EventEntry.Source::Report;
        EventEntry."Original PSP Reference" := 'PSP-DIFFERENT';
        EventEntry."Shopper Reference" := 'CUST-B';
        Reconciler.ReconcilePositiveLifecycleWithResult(EventEntry, DispositionReason, LifecycleApplied);

        Payment.Get('MerchantA', 'PSP-DIFFERENT');
        AssertTrue(Payment.Status = Payment.Status::DataConflict, 'A report difference must create a data conflict.');
        AssertEqualDecimal(100, Payment.Amount, 'The report must not overwrite authoritative payment amount.');
        AssertEqualText('CUST-A', Payment."Shopper Reference", 'The report must not overwrite authoritative customer data.');
        AssertEqualInteger(700001, Payment."Posted Payment Entry No.", 'A data conflict must preserve the posted ledger link.');
    end;

    [Test]
    procedure ConflictingRetransmissionIsQuarantined()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        PaymentState: Codeunit "Adyen Payment State";
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-CONFLICT', 100, 20260903D, 'LOGICAL-FIRST');
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-CONFLICT', 101, 20260904D, 'LOGICAL-CONFLICT');
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);

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
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-ORDER', 100, 20260904D, 'LOGICAL-NEW');
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-ORDER', 200, 20260903D, 'LOGICAL-OLD');
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);

        Payment.Get('MerchantA', 'PSP-ORDER');
        AssertEqualDecimal(100, Payment.Amount, 'An older event must not overwrite a newer payment state.');
        AssertTrue(Payment.Status <> Payment.Status::DataConflict, 'An older event must be ignored, not treated as a new conflict.');
    end;

    [Test]
    procedure OlderCancellationCannotRegressSettledLifecycle()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        PaymentState: Codeunit "Adyen Payment State";
        Reconciler: Codeunit "Adyen Report Reconciler";
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-STALE-CANCEL', 100, 20260901D, 'STALE-CANCEL-AUTH');
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);
        BuildEvent(EventEntry, 'MerchantA', 'Settled', 'PSP-STALE-CANCEL', 100, 20260903D, 'STALE-CANCEL-SETTLED');
        EventEntry.Source := EventEntry.Source::Report;
        EventEntry."Original PSP Reference" := 'PSP-STALE-CANCEL';
        Reconciler.ReconcilePositiveLifecycleWithResult(EventEntry, DispositionReason, LifecycleApplied);

        BuildEvent(EventEntry, 'MerchantA', 'Cancelled', 'MOD-STALE-CANCEL', 100, 20260902D, 'STALE-CANCEL-OLDER');
        EventEntry."Original PSP Reference" := 'PSP-STALE-CANCEL';
        PaymentState.ApplyAdverseEventWithResult(EventEntry, DispositionReason, LifecycleApplied);

        Payment.Get('MerchantA', 'PSP-STALE-CANCEL');
        AssertTrue(Payment."Adyen Lifecycle Status" = Payment."Adyen Lifecycle Status"::Settled, 'An older cancellation must not regress a settled lifecycle.');
        AssertTrue(Payment.Status <> Payment.Status::ReversalRequired, 'An older adverse event must not create a new BC action.');
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
        EventDisposition: Codeunit "Adyen Event Disposition";
        EventWorker: Codeunit "Adyen Event Worker";
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-FAILED', 100, 20260903D, 'LOGICAL-FAILED');
        EventEntry."Transport ID" := 'TRANSPORT-FAILED';
        EventEntry.Success := false;
        EventEntry.Reason := 'Refused by issuer';
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);

        EventEntry.Get('TRANSPORT-FAILED');
        AssertTrue(EventEntry.Status = EventEntry.Status::Ignored, 'A failed authorisation must be ignored.');
        AssertTrue(EventEntry."Lifecycle Effect" = EventEntry."Lifecycle Effect"::NotApplied, 'A failed authorisation must be recorded as not applied to a payment lifecycle.');
        AssertEqualText(EventDisposition.GetUnsuccessfulAuthorisationReason(), EventEntry."Disposition Reason", 'A failed authorisation must explain BC''s disposition.');
        AssertEqualText('Refused by issuer', EventEntry.Reason, 'BC disposition must not overwrite Adyen''s original reason.');
        AssertFalse(Payment.Get('MerchantA', 'PSP-FAILED'), 'A failed authorisation must not create a payment.');
    end;

    [Test]
    procedure MissingAuthorisationSuccessIsIgnoredWithDistinctReason()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        EventDisposition: Codeunit "Adyen Event Disposition";
        EventWorker: Codeunit "Adyen Event Worker";
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-MISSING-SUCCESS', 100, 20260903D, 'LOGICAL-MISSING-SUCCESS');
        EventEntry."Transport ID" := 'TRANSPORT-MISSING-SUCCESS';
        EventEntry."Success Provided" := false;
        EventEntry.Reason := 'Source reason retained';
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);

        EventEntry.Get('TRANSPORT-MISSING-SUCCESS');
        AssertTrue(EventEntry.Status = EventEntry.Status::Ignored, 'An authorisation without a valid success value must be ignored.');
        AssertEqualText(EventDisposition.GetMissingAuthorisationSuccessReason(), EventEntry."Disposition Reason", 'A missing success value needs its own disposition reason.');
        AssertEqualText('Source reason retained', EventEntry.Reason, 'BC disposition must leave the Adyen reason unchanged.');
        AssertFalse(Payment.Get('MerchantA', 'PSP-MISSING-SUCCESS'), 'An authorisation without success must not create a payment.');
    end;

    [Test]
    procedure UnsupportedEventIsIgnoredWithNormalizedType()
    var
        EventEntry: Record "Adyen Event Entry";
        EventDisposition: Codeunit "Adyen Event Disposition";
        EventWorker: Codeunit "Adyen Event Worker";
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'PAYOUT_DECLINE', 'PSP-UNSUPPORTED', 100, 20260903D, 'LOGICAL-UNSUPPORTED');
        EventEntry."Transport ID" := 'TRANSPORT-UNSUPPORTED';
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);

        EventEntry.Get('TRANSPORT-UNSUPPORTED');
        AssertTrue(EventEntry.Status = EventEntry.Status::Ignored, 'An unsupported event must be ignored.');
        AssertTrue(EventEntry."Lifecycle Effect" = EventEntry."Lifecycle Effect"::NotApplied, 'An unsupported event must be recorded as not applied to the payment lifecycle.');
        AssertEqualText(EventDisposition.GetUnsupportedEventReason('PAYOUTDECLINE'), EventEntry."Disposition Reason", 'The reason must identify the normalized unsupported event type.');
    end;

    [Test]
    procedure ReportCancellationAndExpiryAfterAuthorisationRequireReview()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        ReportRun: Record "Adyen Report Run";
        EventWorker: Codeunit "Adyen Event Worker";
        PaymentState: Codeunit "Adyen Payment State";
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigureMerchants();
        ReportRun.Init();
        ReportRun."Merchant Account" := 'MerchantA';
        ReportRun."External Report ID" := 'payments_2026_09_04.csv';
        ReportRun."Download URL" := 'https://ca-test.adyen.com/report.csv';
        ReportRun.Insert(true);
        ReportRun.Status := ReportRun.Status::Ready;
        ReportRun.Modify(true);

        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-REPORT-CANCELLED', 100, 20260903D, 'LOGICAL-AUTH-CANCELLED');
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);
        BuildEvent(EventEntry, 'MerchantA', 'Cancelled', 'MOD-REPORT-CANCELLED', 100, 20260904D, 'LOGICAL-REPORT-CANCELLED');
        EventEntry."Original PSP Reference" := 'PSP-REPORT-CANCELLED';
        EventEntry."Transport ID" := 'TRANSPORT-REPORT-CANCELLED';
        EventEntry.Source := EventEntry.Source::Report;
        EventEntry."Report Run Entry No." := ReportRun."Entry No.";
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);

        Payment.Get('MerchantA', 'PSP-REPORT-CANCELLED');
        AssertTrue(Payment.Status = Payment.Status::ReversalRequired, 'A cancelled authorised payment must require reversal review.');
        AssertTrue(Payment."Adyen Lifecycle Status" = Payment."Adyen Lifecycle Status"::Cancelled, 'The report cancellation must set the lifecycle status.');
        EventEntry.Get('TRANSPORT-REPORT-CANCELLED');
        AssertTrue(EventEntry.Status = EventEntry.Status::Processed, 'A supported cancelled report event must be processed.');

        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-REPORT-EXPIRED', 100, 20260903D, 'LOGICAL-AUTH-EXPIRED');
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);
        BuildEvent(EventEntry, 'MerchantA', 'Expired', 'PSP-REPORT-EXPIRED', 100, 20260904D, 'LOGICAL-REPORT-EXPIRED');
        EventEntry."Original PSP Reference" := 'PSP-REPORT-EXPIRED';
        EventEntry."Transport ID" := 'TRANSPORT-REPORT-EXPIRED';
        EventEntry.Source := EventEntry.Source::Report;
        EventEntry."Report Run Entry No." := ReportRun."Entry No.";
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);

        Payment.Get('MerchantA', 'PSP-REPORT-EXPIRED');
        AssertTrue(Payment.Status = Payment.Status::ReversalRequired, 'An expired authorised payment must require reversal review.');
        AssertTrue(Payment."Adyen Lifecycle Status" = Payment."Adyen Lifecycle Status"::Expired, 'The report expiry must set the lifecycle status.');
        EventEntry.Get('TRANSPORT-REPORT-EXPIRED');
        AssertTrue(EventEntry.Status = EventEntry.Status::Processed, 'A supported expired report event must be processed.');
    end;

    [Test]
    procedure WebhookCancellationAndExpiryAfterAuthorisationRequireReview()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        EventWorker: Codeunit "Adyen Event Worker";
        PaymentState: Codeunit "Adyen Payment State";
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-WEBHOOK-CANCELLED', 100, 20260903D, 'LOGICAL-AUTH-WEBHOOK-CANCELLED');
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);
        BuildEvent(EventEntry, 'MerchantA', 'CANCELLATION', 'MOD-WEBHOOK-CANCELLED', 100, 20260904D, 'LOGICAL-WEBHOOK-CANCELLATION');
        EventEntry."Original PSP Reference" := 'PSP-WEBHOOK-CANCELLED';
        EventEntry."Transport ID" := 'TRANSPORT-WEBHOOK-CANCELLATION';
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);

        Payment.Get('MerchantA', 'PSP-WEBHOOK-CANCELLED');
        AssertTrue(Payment.Status = Payment.Status::ReversalRequired, 'A successful cancellation webhook must require reversal review.');
        EventEntry.Get('TRANSPORT-WEBHOOK-CANCELLATION');
        AssertTrue(EventEntry.Status = EventEntry.Status::Processed, 'A supported cancellation webhook must be processed.');

        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-WEBHOOK-EXPIRED', 100, 20260903D, 'LOGICAL-AUTH-WEBHOOK-EXPIRED');
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);
        BuildEvent(EventEntry, 'MerchantA', 'EXPIRE', 'PSP-WEBHOOK-EXPIRED', 100, 20260904D, 'LOGICAL-WEBHOOK-EXPIRE');
        EventEntry."Transport ID" := 'TRANSPORT-WEBHOOK-EXPIRE';
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);

        Payment.Get('MerchantA', 'PSP-WEBHOOK-EXPIRED');
        AssertTrue(Payment.Status = Payment.Status::ReversalRequired, 'An expire webhook must require reversal review.');
        EventEntry.Get('TRANSPORT-WEBHOOK-EXPIRE');
        AssertTrue(EventEntry.Status = EventEntry.Status::Processed, 'A supported expire webhook must be processed.');
    end;

    [Test]
    procedure UnsuccessfulCancellationIsProcessedWithoutPaymentChange()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        EventDisposition: Codeunit "Adyen Event Disposition";
        EventWorker: Codeunit "Adyen Event Worker";
        PaymentState: Codeunit "Adyen Payment State";
        OriginalStatus: Enum "Adyen Payment Status";
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-CANCEL-FAILED', 100, 20260903D, 'LOGICAL-AUTH-CANCEL-FAILED');
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);
        Payment.Get('MerchantA', 'PSP-CANCEL-FAILED');
        OriginalStatus := Payment.Status;

        BuildEvent(EventEntry, 'MerchantA', 'CANCELLATION', 'MOD-CANCEL-FAILED', 100, 20260904D, 'LOGICAL-CANCEL-FAILED');
        EventEntry."Original PSP Reference" := 'PSP-CANCEL-FAILED';
        EventEntry."Transport ID" := 'TRANSPORT-CANCEL-FAILED';
        EventEntry.Success := false;
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);

        Payment.Get('MerchantA', 'PSP-CANCEL-FAILED');
        AssertTrue(Payment.Status = OriginalStatus, 'An unsuccessful cancellation must not change the payment state.');
        EventEntry.Get('TRANSPORT-CANCEL-FAILED');
        AssertTrue(EventEntry.Status = EventEntry.Status::Processed, 'An unsuccessful cancellation is an intentional processed no-op.');
        AssertEqualText(EventDisposition.GetUnsuccessfulAdverseReason('CANCELLATION'), EventEntry."Disposition Reason", 'An unsuccessful cancellation needs a disposition reason.');
    end;

    [Test]
    procedure DuplicateLogicalEventIsProcessedWithNoOpReason()
    var
        EventEntry: Record "Adyen Event Entry";
        EventDisposition: Codeunit "Adyen Event Disposition";
        EventWorker: Codeunit "Adyen Event Worker";
        PaymentState: Codeunit "Adyen Payment State";
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-DUPLICATE', 100, 20260903D, 'LOGICAL-DUPLICATE');
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);

        EventEntry."Transport ID" := 'TRANSPORT-DUPLICATE';
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);

        EventEntry.Get('TRANSPORT-DUPLICATE');
        AssertTrue(EventEntry.Status = EventEntry.Status::Processed, 'A duplicate logical event is an intentional processed no-op.');
        AssertTrue(EventEntry."Lifecycle Effect" = EventEntry."Lifecycle Effect"::NotApplied, 'A duplicate logical event must be recorded as not applied.');
        AssertEqualText(EventDisposition.GetDuplicateLogicalEventReason(), EventEntry."Disposition Reason", 'A duplicate logical event needs a disposition reason.');
    end;

    [Test]
    procedure OlderEventIsProcessedWithNoOpReason()
    var
        EventEntry: Record "Adyen Event Entry";
        EventDisposition: Codeunit "Adyen Event Disposition";
        EventWorker: Codeunit "Adyen Event Worker";
        PaymentState: Codeunit "Adyen Payment State";
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-STALE', 100, 20260904D, 'LOGICAL-NEWEST');
        PaymentState.ImportPositivePaymentWithResult(EventEntry, false, DispositionReason, LifecycleApplied);

        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-STALE', 200, 20260903D, 'LOGICAL-OLDER');
        EventEntry."Transport ID" := 'TRANSPORT-OLDER';
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);

        EventEntry.Get('TRANSPORT-OLDER');
        AssertTrue(EventEntry.Status = EventEntry.Status::Processed, 'An older event is an intentional processed no-op.');
        AssertTrue(EventEntry."Lifecycle Effect" = EventEntry."Lifecycle Effect"::NotApplied, 'An older event must be recorded as not applied.');
        AssertEqualText(EventDisposition.GetOlderEventReason(), EventEntry."Disposition Reason", 'An older event needs a disposition reason.');
    end;

    [Test]
    procedure EventWorkerRecordsLifecycleTransitionEffects()
    var
        EventEntry: Record "Adyen Event Entry";
        ReportRun: Record "Adyen Report Run";
        EventWorker: Codeunit "Adyen Event Worker";
    begin
        ConfigureMerchants();
        ReportRun.Init();
        ReportRun."Merchant Account" := 'MerchantA';
        ReportRun."External Report ID" := 'lifecycle_effects_2026_09_05.csv';
        ReportRun."Download URL" := 'https://ca-test.adyen.com/report.csv';
        ReportRun.Insert(true);
        ReportRun.Status := ReportRun.Status::Ready;
        ReportRun.Modify(true);

        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-EFFECTS', 100, 20260901D, 'EFFECTS-AUTH');
        EventEntry."Transport ID" := 'TRANSPORT-EFFECTS-AUTH';
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);
        EventEntry.Get('TRANSPORT-EFFECTS-AUTH');
        AssertTrue(EventEntry."Lifecycle Effect" = EventEntry."Lifecycle Effect"::Changed, 'Creating an authorised payment must record a lifecycle change.');
        AssertTrue(EventEntry."Previous Lifecycle Status" = EventEntry."Previous Lifecycle Status"::Unknown, 'A newly created payment has no earlier recorded lifecycle.');
        AssertTrue(EventEntry."Resulting Lifecycle Status" = EventEntry."Resulting Lifecycle Status"::Authorised, 'The authorisation must record its resulting lifecycle.');

        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-EFFECTS', 100, 20260902D, 'EFFECTS-AUTH-REPEAT');
        EventEntry."Transport ID" := 'TRANSPORT-EFFECTS-AUTH-REPEAT';
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);
        EventEntry.Get('TRANSPORT-EFFECTS-AUTH-REPEAT');
        AssertTrue(EventEntry."Lifecycle Effect" = EventEntry."Lifecycle Effect"::AppliedWithoutChange, 'A new event that repeats the current lifecycle must be recorded as applied without change.');
        AssertTrue(EventEntry."Previous Lifecycle Status" = EventEntry."Previous Lifecycle Status"::Authorised, 'The repeated authorisation must retain the prior lifecycle.');
        AssertTrue(EventEntry."Resulting Lifecycle Status" = EventEntry."Resulting Lifecycle Status"::Authorised, 'The repeated authorisation must retain the resulting lifecycle.');

        BuildEvent(EventEntry, 'MerchantA', 'SentForSettle', 'PSP-EFFECTS', 100, 20260903D, 'EFFECTS-SENT');
        EventEntry."Transport ID" := 'TRANSPORT-EFFECTS-SENT';
        EventEntry.Source := EventEntry.Source::Report;
        EventEntry."Report Run Entry No." := ReportRun."Entry No.";
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);
        EventEntry.Get('TRANSPORT-EFFECTS-SENT');
        AssertLifecycleTransition(EventEntry, Enum::"Adyen Lifecycle Status"::Authorised, Enum::"Adyen Lifecycle Status"::SentForSettle, 'SentForSettle');

        BuildEvent(EventEntry, 'MerchantA', 'SETTLED_REVERSED', 'MOD-EFFECTS-REVERSED', 100, 20260904D, 'EFFECTS-REVERSED');
        EventEntry."Original PSP Reference" := 'PSP-EFFECTS';
        EventEntry."Transport ID" := 'TRANSPORT-EFFECTS-REVERSED';
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);
        EventEntry.Get('TRANSPORT-EFFECTS-REVERSED');
        AssertLifecycleTransition(EventEntry, Enum::"Adyen Lifecycle Status"::SentForSettle, Enum::"Adyen Lifecycle Status"::SettledReversed, 'SettledReversed');

        BuildEvent(EventEntry, 'MerchantA', 'Settled', 'PSP-EFFECTS', 100, 20260905D, 'EFFECTS-RECOVERY');
        EventEntry."Transport ID" := 'TRANSPORT-EFFECTS-RECOVERY';
        EventEntry.Source := EventEntry.Source::Report;
        EventEntry."Report Run Entry No." := ReportRun."Entry No.";
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);
        EventEntry.Get('TRANSPORT-EFFECTS-RECOVERY');
        AssertLifecycleTransition(EventEntry, Enum::"Adyen Lifecycle Status"::SettledReversed, Enum::"Adyen Lifecycle Status"::Settled, 'Settlement recovery');
    end;

    [Test]
    procedure FailedProcessingLeavesLifecycleEffectUnknownUntilRetrySucceeds()
    var
        EventEntry: Record "Adyen Event Entry";
        ReportRun: Record "Adyen Report Run";
        EventWorker: Codeunit "Adyen Event Worker";
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'SentForSettle', 'PSP-EFFECT-RETRY', 100, 20260903D, 'EFFECT-RETRY');
        EventEntry."Transport ID" := 'TRANSPORT-EFFECT-RETRY';
        EventEntry.Source := EventEntry.Source::Report;
        EventEntry."Report Run Entry No." := 2147483647;
        EventEntry.Insert(true);
        Commit();

        if Codeunit.Run(Codeunit::"Adyen Event Worker", EventEntry) then
            Error('Processing an event for a missing report run must fail.');
        EventEntry.Get('TRANSPORT-EFFECT-RETRY');
        AssertTrue(EventEntry."Lifecycle Effect" = EventEntry."Lifecycle Effect"::Unknown, 'A rolled-back processing attempt must not retain a lifecycle result.');

        ReportRun.Init();
        ReportRun."Merchant Account" := 'MerchantA';
        ReportRun."External Report ID" := 'lifecycle_retry_2026_09_03.csv';
        ReportRun."Download URL" := 'https://ca-test.adyen.com/report.csv';
        ReportRun.Insert(true);
        ReportRun.Status := ReportRun.Status::Ready;
        ReportRun.Modify(true);
        EventEntry."Report Run Entry No." := ReportRun."Entry No.";
        EventEntry.Modify(true);
        EventWorker.Run(EventEntry);

        EventEntry.Get('TRANSPORT-EFFECT-RETRY');
        AssertTrue(EventEntry."Lifecycle Effect" = EventEntry."Lifecycle Effect"::Changed, 'A successful retry must record the lifecycle result.');
        AssertTrue(EventEntry."Resulting Lifecycle Status" = EventEntry."Resulting Lifecycle Status"::SentForSettle, 'The retry must record its resulting lifecycle.');
    end;

    [Test]
    procedure PositiveEventBlockedByReversalReviewHasNoOpReason()
    var
        EventEntry: Record "Adyen Event Entry";
        EventDisposition: Codeunit "Adyen Event Disposition";
        EventWorker: Codeunit "Adyen Event Worker";
        PaymentState: Codeunit "Adyen Payment State";
        DispositionReason: Text[250];
        LifecycleApplied: Boolean;
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'SETTLED_REVERSED', 'PSP-REVERSAL', 100, 20260903D, 'LOGICAL-REVERSAL');
        EventEntry."Original PSP Reference" := 'PSP-REVERSAL';
        PaymentState.ApplyAdverseEventWithResult(EventEntry, DispositionReason, LifecycleApplied);

        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-REVERSAL', 100, 20260904D, 'LOGICAL-POSITIVE-AFTER-REVERSAL');
        EventEntry."Transport ID" := 'TRANSPORT-REVERSAL-BLOCK';
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);

        EventEntry.Get('TRANSPORT-REVERSAL-BLOCK');
        AssertTrue(EventEntry.Status = EventEntry.Status::Processed, 'A reversal-blocked positive event is an intentional processed no-op.');
        AssertEqualText(EventDisposition.GetReversalReviewReason(), EventEntry."Disposition Reason", 'A reversal-blocked event needs a disposition reason.');
    end;

    [Test]
    procedure UnsuccessfulAdverseEventIsProcessedWithNoOpReason()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        EventDisposition: Codeunit "Adyen Event Disposition";
        EventWorker: Codeunit "Adyen Event Worker";
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'REFUNDED', 'PSP-FAILED-REFUND', 100, 20260903D, 'LOGICAL-FAILED-REFUND');
        EventEntry."Transport ID" := 'TRANSPORT-FAILED-REFUND';
        EventEntry.Success := false;
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);

        EventEntry.Get('TRANSPORT-FAILED-REFUND');
        AssertTrue(EventEntry.Status = EventEntry.Status::Processed, 'An unsuccessful adverse event requiring no change is a processed no-op.');
        AssertEqualText(EventDisposition.GetUnsuccessfulAdverseReason('REFUNDED'), EventEntry."Disposition Reason", 'An unsuccessful adverse event needs a disposition reason.');
        AssertFalse(Payment.Get('MerchantA', 'PSP-FAILED-REFUND'), 'An unsuccessful refund must not create a reversal-review payment.');
    end;

    [Test]
    procedure SuccessfulRetryClearsPreviousDispositionReason()
    var
        EventEntry: Record "Adyen Event Entry";
        EventWorker: Codeunit "Adyen Event Worker";
    begin
        ConfigureMerchants();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-RETRY-CLEAR', 100, 20260903D, 'LOGICAL-RETRY-CLEAR');
        EventEntry."Transport ID" := 'TRANSPORT-RETRY-CLEAR';
        EventEntry."Disposition Reason" := 'Stale reason from an earlier attempt';
        EventEntry.Insert(true);
        EventWorker.Run(EventEntry);

        EventEntry.Get('TRANSPORT-RETRY-CLEAR');
        AssertTrue(EventEntry.Status = EventEntry.Status::Processed, 'The successful retry must be processed.');
        AssertEqualText('', EventEntry."Disposition Reason", 'Beginning a genuine retry must clear stale disposition text.');
    end;

    [Test]
    procedure FreshEventsAndPaymentsInitializeAndRetainAuditData()
    var
        EventEntry: Record "Adyen Event Entry";
        Payment: Record "Imported Adyen Payment";
        EventWorker: Codeunit "Adyen Event Worker";
        StartedAt: DateTime;
        CreatedAt: DateTime;
    begin
        ConfigureMerchants();
        StartedAt := CurrentDateTime();
        BuildEvent(EventEntry, 'MerchantA', 'AUTHORISATION', 'PSP-FRESH-AUDIT', 100, 20260903D, 'LOGICAL-FRESH-AUTH');
        EventEntry."Transport ID" := 'TRANSPORT-FRESH-AUTH';
        EventEntry.Insert(true);
        AssertEqualText('PSP-FRESH-AUDIT', EventEntry."Payment PSP Reference", 'A new event must initialize its payment reference from its PSP reference.');
        AssertTrue(EventEntry."Lifecycle Effect" = EventEntry."Lifecycle Effect"::Unknown, 'An unprocessed event must not claim a processing outcome.');

        EventWorker.Run(EventEntry);

        Payment.Get('MerchantA', 'PSP-FRESH-AUDIT');
        CreatedAt := Payment."Created At UTC";
        AssertTrue((CreatedAt >= StartedAt) and (CreatedAt <= CurrentDateTime()), 'Fresh import must record its actual creation time.');
        AssertTrue(Payment."Modified At UTC" >= CreatedAt, 'The modification timestamp must be initialized with the payment.');
        AssertTrue(Payment."Posting Origin" = Payment."Posting Origin"::Unclassified, 'An unposted payment must have no classified posting route.');
        EventEntry.Get('TRANSPORT-FRESH-AUTH');
        AssertTrue(EventEntry."Previous Lifecycle Status" = EventEntry."Previous Lifecycle Status"::Unknown, 'A newly created payment has no previous lifecycle.');
        AssertTrue(EventEntry."Resulting Lifecycle Status" = EventEntry."Resulting Lifecycle Status"::Authorised, 'The authorisation outcome must be recorded during processing.');
        AssertTrue(EventEntry."Lifecycle Effect" = EventEntry."Lifecycle Effect"::Changed, 'Creating the payment must record a changed lifecycle.');
        AssertTrue(EventEntry."Processed At UTC" >= StartedAt, 'The event must retain its processing timestamp.');

        BuildEvent(EventEntry, 'MerchantA', 'CANCELLATION', 'MOD-FRESH-CANCEL', 100, 20260904D, 'LOGICAL-FRESH-CANCEL');
        EventEntry."Original PSP Reference" := 'PSP-FRESH-AUDIT';
        EventEntry."Transport ID" := 'TRANSPORT-FRESH-CANCEL';
        EventEntry.Insert(true);
        AssertEqualText('PSP-FRESH-AUDIT', EventEntry."Payment PSP Reference", 'A new modification event must initialize its reference from the original payment.');

        EventWorker.Run(EventEntry);

        Payment.Get('MerchantA', 'PSP-FRESH-AUDIT');
        AssertTrue(Payment."Created At UTC" = CreatedAt, 'Later lifecycle processing must preserve the original creation timestamp.');
        AssertTrue(Payment.Status = Payment.Status::ReversalRequired, 'Cancellation must retain the finance-review workflow.');
        EventEntry.Get('TRANSPORT-FRESH-CANCEL');
        AssertTrue(EventEntry."Previous Lifecycle Status" = EventEntry."Previous Lifecycle Status"::Authorised, 'Cancellation must retain its previous lifecycle.');
        AssertTrue(EventEntry."Resulting Lifecycle Status" = EventEntry."Resulting Lifecycle Status"::Cancelled, 'Cancellation must retain its resulting lifecycle.');
        AssertTrue(EventEntry."Lifecycle Effect" = EventEntry."Lifecycle Effect"::Changed, 'Cancellation must retain its recorded lifecycle effect.');
        EventEntry.Get('TRANSPORT-FRESH-AUTH');
        AssertTrue(EventEntry."Resulting Lifecycle Status" = EventEntry."Resulting Lifecycle Status"::Authorised, 'A later event must not rewrite the earlier event outcome.');
    end;

    local procedure ConfigureMerchants()
    var
        Merchant: Record "Adyen Merchant";
        MethodPolicy: Record "Adyen Merchant Method Policy";
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

    local procedure AssertLifecycleMapping(PaymentState: Codeunit "Adyen Payment State"; MessageType: Text; Expected: Enum "Adyen Lifecycle Status")
    var
        Actual: Enum "Adyen Lifecycle Status";
    begin
        AssertTrue(PaymentState.TryGetLifecycleStatus(MessageType, Actual), StrSubstNo('%1 must be a supported lifecycle event.', MessageType));
        AssertTrue(Actual = Expected, StrSubstNo('%1 maps to the wrong lifecycle value.', MessageType));
    end;

    local procedure AssertLifecycleTransition(EventEntry: Record "Adyen Event Entry"; ExpectedPrevious: Enum "Adyen Lifecycle Status"; ExpectedResulting: Enum "Adyen Lifecycle Status"; Context: Text)
    begin
        AssertTrue(EventEntry."Lifecycle Effect" = EventEntry."Lifecycle Effect"::Changed, StrSubstNo('%1 must be recorded as a lifecycle change.', Context));
        AssertTrue(EventEntry."Previous Lifecycle Status" = ExpectedPrevious, StrSubstNo('%1 has the wrong previous lifecycle.', Context));
        AssertTrue(EventEntry."Resulting Lifecycle Status" = ExpectedResulting, StrSubstNo('%1 has the wrong resulting lifecycle.', Context));
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
