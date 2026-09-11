codeunit 72035 "Adyen Payment State"
{
    procedure ImportPositivePaymentWithResult(EventEntry: Record "Adyen Event Entry"; Backfilled: Boolean; var DispositionReason: Text[250]; var LifecycleApplied: Boolean)
    var
        Payment: Record "Imported Adyen Payment";
        Merchant: Record "Adyen Merchant";
        EventDisposition: Codeunit "Adyen Event Disposition";
        Matcher: Codeunit "Adyen Invoice Matcher";
        Poster: Codeunit "Adyen Payment Poster";
        PaymentReference: Code[50];
        IsNew: Boolean;
    begin
        Clear(DispositionReason);
        LifecycleApplied := false;
        PaymentReference := GetOriginalPaymentReference(EventEntry);
        IsNew := not Payment.Get(EventEntry."Merchant Account", PaymentReference);
        if IsNew then begin
            Payment.Init();
            Payment."Merchant Account" := EventEntry."Merchant Account";
            Payment."PSP Reference" := PaymentReference;
            Payment.Status := Payment.Status::Imported;
            Payment.Insert(true);
        end;

        LifecycleApplied := ApplyLifecycleToPayment(Payment, EventEntry, DispositionReason);
        if not LifecycleApplied then
            exit;

        if (not IsNew) and (Payment.Status = Payment.Status::ReversalRequired) then begin
            Payment.Modify(true);
            DispositionReason := EventDisposition.GetReversalReviewReason();
            exit;
        end;

        if (not IsNew) and not HasSameAuthoritativeData(Payment, EventEntry) then begin
            MarkDataConflict(Payment, EventEntry);
            Payment.Modify(true);
            exit;
        end;

        Payment."Merchant Reference" := EventEntry."Merchant Reference";
        Payment."Shopper Reference" := EventEntry."Shopper Reference";
        Payment."Payment Method" := EventEntry."Payment Method";
        Payment."Currency Code" := EventEntry."Currency Code";
        Payment.Amount := EventEntry.Amount;
        if Payment."Event Date-Time" = 0DT then
            Payment."Event Date-Time" := EventEntry."Occurred At UTC";
        if IsNew then
            Payment."Origin Source" := EventEntry.Source;
        Payment.Backfilled := Payment.Backfilled or Backfilled;

        if Payment.Status in [Payment.Status::PostedApplied, Payment.Status::ManuallyReconciled, Payment.Status::ManualJournalCreated, Payment.Status::DataConflict] then begin
            Payment.Modify(true);
            exit;
        end;

        Matcher.Match(Payment);
        if Payment."Match Result" = Payment."Match Result"::UniqueExact then begin
            Payment.Status := Payment.Status::ReadyToPost;
            Payment.Modify(true);
            Merchant.Get(Payment."Merchant Account");
            if Merchant."Auto Post" then
                Poster.PostAndApplyAutomatically(Payment);
        end else begin
            Payment.Status := Payment.Status::Imported;
            Payment.Modify(true);
        end;
    end;

    procedure ApplyAdverseEventWithResult(EventEntry: Record "Adyen Event Entry"; var DispositionReason: Text[250]; var LifecycleApplied: Boolean)
    var
        Payment: Record "Imported Adyen Payment";
        EventDisposition: Codeunit "Adyen Event Disposition";
        PaymentReference: Code[50];
        IsNew: Boolean;
    begin
        Clear(DispositionReason);
        LifecycleApplied := false;
        if not IsAdverseMessage(EventEntry."Message Type") then
            exit;
        if EventEntry."Success Provided" and not EventEntry.Success and
           not (EventDisposition.NormalizeMessageType(EventEntry."Message Type") in ['CAPTUREFAILED', 'REFUNDFAILED'])
        then begin
            DispositionReason := EventDisposition.GetUnsuccessfulAdverseReason(EventEntry."Message Type");
            exit;
        end;

        PaymentReference := GetOriginalPaymentReference(EventEntry);
        IsNew := not Payment.Get(EventEntry."Merchant Account", PaymentReference);
        if IsNew then begin
            Payment.Init();
            Payment."Merchant Account" := EventEntry."Merchant Account";
            Payment."PSP Reference" := PaymentReference;
            Payment."Merchant Reference" := EventEntry."Merchant Reference";
            Payment."Shopper Reference" := EventEntry."Shopper Reference";
            Payment."Payment Method" := EventEntry."Payment Method";
            Payment."Currency Code" := EventEntry."Currency Code";
            Payment.Amount := EventEntry.Amount;
            Payment."Event Date-Time" := EventEntry."Occurred At UTC";
            Payment."Origin Source" := EventEntry.Source;
            Payment.Backfilled := EventEntry.Source = EventEntry.Source::Report;
            Payment.Insert(true);
        end;

        LifecycleApplied := ApplyLifecycleToPayment(Payment, EventEntry, DispositionReason);
        if not LifecycleApplied then
            exit;

        Payment.Status := Payment.Status::ReversalRequired;
        Payment."Exception Message" := CopyStr(
            StrSubstNo('%1 received for merchant %2 payment %3. Finance review is required.',
                EventEntry."Message Type", EventEntry."Merchant Account", PaymentReference),
            1, MaxStrLen(Payment."Exception Message"));
        Payment.Modify(true);
    end;

    procedure ApplyLifecycleToPayment(var Payment: Record "Imported Adyen Payment"; EventEntry: Record "Adyen Event Entry"; var DispositionReason: Text[250]): Boolean
    var
        EventDisposition: Codeunit "Adyen Event Disposition";
        LifecycleStatus: Enum "Adyen Lifecycle Status";
    begin
        if not TryGetLifecycleStatus(EventEntry."Message Type", LifecycleStatus) then
            exit(false);

        if (Payment."Latest Event At UTC" <> 0DT) and
           (EventEntry."Occurred At UTC" < Payment."Latest Event At UTC")
        then begin
            DispositionReason := EventDisposition.GetOlderEventReason();
            exit(false);
        end;
        if (Payment."Latest Logical Event Key" <> '') and
           (Payment."Latest Logical Event Key" = EventEntry."Logical Event Key")
        then begin
            DispositionReason := EventDisposition.GetDuplicateLogicalEventReason();
            exit(false);
        end;
        if (Payment."Latest Event At UTC" <> 0DT) and
           (EventEntry."Occurred At UTC" = Payment."Latest Event At UTC") and
           (GetLifecycleRank(LifecycleStatus) < GetLifecycleRank(Payment."Adyen Lifecycle Status"))
        then begin
            DispositionReason := EventDisposition.GetOlderEventReason();
            exit(false);
        end;

        Payment."Adyen Lifecycle Status" := LifecycleStatus;
        Payment."Latest Event At UTC" := EventEntry."Occurred At UTC";
        Payment."Latest Logical Event Key" := EventEntry."Logical Event Key";
        exit(true);
    end;

    procedure MarkDataConflict(var Payment: Record "Imported Adyen Payment"; EventEntry: Record "Adyen Event Entry")
    begin
        if Payment.Status = Payment.Status::ReversalRequired then
            exit;
        Payment.Status := Payment.Status::DataConflict;
        if EventEntry.Source = EventEntry.Source::Report then
            Payment."Exception Message" := CopyStr(
                StrSubstNo('Report row %1 differs from payment %2 for customer, currency, or amount.',
                    EventEntry."Report Row No.", Payment."PSP Reference"),
                1, MaxStrLen(Payment."Exception Message"))
        else
            Payment."Exception Message" := CopyStr(
                StrSubstNo('%1 differs from payment %2 for merchant reference, customer, payment method, currency, or amount.',
                    EventEntry."Message Type", Payment."PSP Reference"),
                1, MaxStrLen(Payment."Exception Message"));
    end;

    procedure HasSameReportData(Payment: Record "Imported Adyen Payment"; EventEntry: Record "Adyen Event Entry"): Boolean
    begin
        exit(
            (Payment."Shopper Reference" = EventEntry."Shopper Reference") and
            (Payment."Currency Code" = EventEntry."Currency Code") and
            (Payment.Amount = EventEntry.Amount));
    end;

    procedure IsAdverseMessage(MessageType: Text): Boolean
    var
        EventDisposition: Codeunit "Adyen Event Disposition";
    begin
        exit(EventDisposition.NormalizeMessageType(MessageType) in [
            'CAPTUREFAILED', 'CANCELLED', 'CANCELLATION', 'EXPIRED', 'EXPIRE',
            'REFUNDED', 'REFUNDFAILED', 'REFUNDEDREVERSED',
            'CHARGEBACK', 'CHARGEBACKREVERSED', 'SECONDCHARGEBACK', 'SETTLEDREVERSED', 'SETTLEMENTREVERSED']);
    end;

    procedure IsPositiveReportMessage(MessageType: Text): Boolean
    var
        EventDisposition: Codeunit "Adyen Event Disposition";
    begin
        exit(EventDisposition.NormalizeMessageType(MessageType) in ['AUTHORISED', 'SENTFORSETTLE', 'SETTLED']);
    end;

    procedure TryGetLifecycleStatus(MessageType: Text; var LifecycleStatus: Enum "Adyen Lifecycle Status"): Boolean
    var
        EventDisposition: Codeunit "Adyen Event Disposition";
    begin
        case EventDisposition.NormalizeMessageType(MessageType) of
            'AUTHORISATION', 'AUTHORISED':
                LifecycleStatus := LifecycleStatus::Authorised;
            'SENTFORSETTLE':
                LifecycleStatus := LifecycleStatus::SentForSettle;
            'SETTLED':
                LifecycleStatus := LifecycleStatus::Settled;
            'CANCELLED', 'CANCELLATION':
                LifecycleStatus := LifecycleStatus::Cancelled;
            'EXPIRED', 'EXPIRE':
                LifecycleStatus := LifecycleStatus::Expired;
            'CAPTUREFAILED':
                LifecycleStatus := LifecycleStatus::CaptureFailed;
            'REFUNDED':
                LifecycleStatus := LifecycleStatus::Refunded;
            'REFUNDFAILED':
                LifecycleStatus := LifecycleStatus::RefundFailed;
            'REFUNDEDREVERSED':
                LifecycleStatus := LifecycleStatus::RefundedReversed;
            'CHARGEBACK':
                LifecycleStatus := LifecycleStatus::Chargeback;
            'CHARGEBACKREVERSED':
                LifecycleStatus := LifecycleStatus::ChargebackReversed;
            'SECONDCHARGEBACK':
                LifecycleStatus := LifecycleStatus::SecondChargeback;
            'SETTLEDREVERSED', 'SETTLEMENTREVERSED':
                LifecycleStatus := LifecycleStatus::SettledReversed;
            else
                exit(false);
        end;
        exit(true);
    end;

    procedure GetOriginalPaymentReference(EventEntry: Record "Adyen Event Entry"): Code[50]
    begin
        if EventEntry."Original PSP Reference" <> '' then
            exit(CopyStr(EventEntry."Original PSP Reference", 1, 50));
        if EventEntry."Payment PSP Reference" <> '' then
            exit(EventEntry."Payment PSP Reference");
        exit(CopyStr(EventEntry."PSP Reference", 1, 50));
    end;

    local procedure HasSameAuthoritativeData(Payment: Record "Imported Adyen Payment"; EventEntry: Record "Adyen Event Entry"): Boolean
    begin
        exit(
            (Payment."Merchant Reference" = EventEntry."Merchant Reference") and
            (Payment."Shopper Reference" = EventEntry."Shopper Reference") and
            (Payment."Payment Method" = EventEntry."Payment Method") and
            (Payment."Currency Code" = EventEntry."Currency Code") and
            (Payment.Amount = EventEntry.Amount));
    end;

    procedure GetLifecycleRank(LifecycleStatus: Enum "Adyen Lifecycle Status"): Integer
    begin
        case LifecycleStatus of
            LifecycleStatus::Unknown:
                exit(0);
            LifecycleStatus::Authorised:
                exit(10);
            LifecycleStatus::SentForSettle:
                exit(20);
            LifecycleStatus::Cancelled,
            LifecycleStatus::Expired,
            LifecycleStatus::CaptureFailed:
                exit(30);
            LifecycleStatus::Settled:
                exit(40);
            LifecycleStatus::Refunded,
            LifecycleStatus::RefundFailed,
            LifecycleStatus::Chargeback,
            LifecycleStatus::SettledReversed:
                exit(50);
            LifecycleStatus::RefundedReversed,
            LifecycleStatus::ChargebackReversed:
                exit(60);
            LifecycleStatus::SecondChargeback:
                exit(70);
        end;
    end;
}
