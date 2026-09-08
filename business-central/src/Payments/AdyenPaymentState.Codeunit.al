codeunit 72035 "Adyen Payment State"
{
    procedure ImportPositivePayment(EventEntry: Record "Adyen Event Entry"; Backfilled: Boolean)
    var
        Payment: Record "Imported Adyen Payment";
        Merchant: Record "Adyen Merchant";
        Matcher: Codeunit "Adyen Invoice Matcher";
        Poster: Codeunit "Adyen Payment Poster";
        PaymentReference: Code[50];
        IsNew: Boolean;
    begin
        PaymentReference := GetOriginalPaymentReference(EventEntry);
        IsNew := not Payment.Get(EventEntry."Merchant Account", PaymentReference);
        if IsNew then begin
            Payment.Init();
            Payment."Merchant Account" := EventEntry."Merchant Account";
            Payment."PSP Reference" := PaymentReference;
            Payment.Status := Payment.Status::Imported;
            Payment."Report Status" := Payment."Report Status"::NotReceived;
            Payment.Insert(true);
        end;

        if Payment.Status = Payment.Status::ReversalRequired then
            exit;
        if (not IsNew) and (EventEntry."Occurred At UTC" < Payment."Latest Event At UTC") then
            exit;
        if (not IsNew) and (Payment."Latest Logical Event Key" = EventEntry."Logical Event Key") then
            exit;
        if (not IsNew) and (Payment."Origin Source" = Payment."Origin Source"::Webhook) and
           not HasSameAuthoritativeData(Payment, EventEntry)
        then begin
            Payment.Status := Payment.Status::DataConflict;
            Payment."Exception Message" := CopyStr(
                StrSubstNo('A later AUTHORISATION for merchant %1 and PSP reference %2 conflicts with the retained payment data.',
                    Payment."Merchant Account", Payment."PSP Reference"),
                1, MaxStrLen(Payment."Exception Message"));
            Payment.Modify(true);
            exit;
        end;
        if (not IsNew) and (Payment."Origin Source" = Payment."Origin Source"::Report) and
           not HasSameAuthoritativeData(Payment, EventEntry)
        then
            Payment."Report Status" := Payment."Report Status"::Discrepancy;

        Payment."Merchant Reference" := EventEntry."Merchant Reference";
        Payment."Shopper Reference" := EventEntry."Shopper Reference";
        Payment."Payment Method" := EventEntry."Payment Method";
        Payment."Currency Code" := EventEntry."Currency Code";
        Payment.Amount := EventEntry.Amount;
        Payment."Event Date-Time" := EventEntry."Occurred At UTC";
        Payment."Latest Event At UTC" := EventEntry."Occurred At UTC";
        Payment."Latest Logical Event Key" := EventEntry."Logical Event Key";
        Payment."Origin Source" := EventEntry.Source;
        Payment.Backfilled := Payment.Backfilled or Backfilled;

        if Payment.Status in [Payment.Status::PostedApplied, Payment.Status::ManuallyReconciled, Payment.Status::ManualJournalCreated] then begin
            Payment.Modify(true);
            exit;
        end;

        Matcher.Match(Payment);
        if Payment."Match Result" = Payment."Match Result"::UniqueExact then begin
            Payment.Status := Payment.Status::ReadyToPost;
            Payment.Modify(true);
            Merchant.Get(Payment."Merchant Account");
            if Merchant."Auto Post" then
                Poster.PostAndApply(Payment);
        end else begin
            Payment.Status := Payment.Status::Imported;
            Payment.Modify(true);
        end;
    end;

    procedure ApplyAdverseEvent(EventEntry: Record "Adyen Event Entry")
    var
        Payment: Record "Imported Adyen Payment";
        PaymentReference: Code[50];
    begin
        if EventEntry."Success Provided" and not EventEntry.Success and
           not (NormalizeMessageType(EventEntry."Message Type") in ['CAPTUREFAILED', 'REFUNDFAILED'])
        then
            exit;

        PaymentReference := GetOriginalPaymentReference(EventEntry);
        if not Payment.Get(EventEntry."Merchant Account", PaymentReference) then begin
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
            Payment.Insert(true);
        end;

        if EventEntry."Occurred At UTC" > Payment."Latest Event At UTC" then begin
            Payment."Latest Event At UTC" := EventEntry."Occurred At UTC";
            Payment."Latest Logical Event Key" := EventEntry."Logical Event Key";
        end;
        Payment.Status := Payment.Status::ReversalRequired;
        if EventEntry.Source = EventEntry.Source::Report then
            Payment."Report Status" := Payment."Report Status"::Discrepancy;
        Payment."Exception Message" := CopyStr(
            StrSubstNo('%1 received for merchant %2 payment %3. Finance review is required.',
                EventEntry."Message Type", EventEntry."Merchant Account", PaymentReference),
            1, MaxStrLen(Payment."Exception Message"));
        Payment.Modify(true);
    end;

    procedure IsAdverseMessage(MessageType: Text): Boolean
    begin
        exit(NormalizeMessageType(MessageType) in [
            'CAPTUREFAILED', 'REFUND', 'REFUNDED', 'REFUNDFAILED', 'REFUNDEDREVERSED',
            'CHARGEBACK', 'CHARGEBACKREVERSED', 'SECONDCHARGEBACK', 'SETTLEDREVERSED', 'SETTLEMENTREVERSED']);
    end;

    procedure GetOriginalPaymentReference(EventEntry: Record "Adyen Event Entry"): Code[50]
    begin
        if EventEntry."Original PSP Reference" <> '' then
            exit(CopyStr(EventEntry."Original PSP Reference", 1, 50));
        exit(CopyStr(EventEntry."PSP Reference", 1, 50));
    end;

    local procedure NormalizeMessageType(MessageType: Text): Text
    begin
        exit(UpperCase(DelChr(MessageType, '=', '_- ')));
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
}
