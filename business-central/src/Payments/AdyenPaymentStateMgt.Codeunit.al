codeunit 72031 "Adyen Payment State Mgt."
{
    procedure ImportPositivePayment(InboxEntry: Record "Adyen Inbox Entry"; Backfilled: Boolean)
    var
        Payment: Record "Imported Adyen Payment";
        Setup: Record "Adyen Setup";
        InvoiceMatcher: Codeunit "Adyen Invoice Matcher";
        PaymentPoster: Codeunit "Adyen Payment Poster";
        PaymentReference: Code[50];
        IsNew: Boolean;
    begin
        PaymentReference := GetOriginalPaymentReference(InboxEntry);
        IsNew := not Payment.Get(PaymentReference);
        if IsNew then begin
            Payment.Init();
            Payment."PSP Reference" := PaymentReference;
            Payment.Status := Payment.Status::Imported;
            Payment."Report Status" := Payment."Report Status"::NotReceived;
            Payment.Insert(true);
        end;

        if Payment.Status = Payment.Status::ReversalRequired then
            exit;
        if (not IsNew) and (InboxEntry."Occurred At UTC" < Payment."Latest Event At UTC") then
            exit;

        Payment."Merchant Reference" := InboxEntry."Merchant Reference";
        Payment."Shopper Reference" := InboxEntry."Shopper Reference";
        Payment."Payment Method" := InboxEntry."Payment Method";
        Payment."Currency Code" := InboxEntry."Currency Code";
        Payment.Amount := InboxEntry.Amount;
        Payment."Event Date-Time" := InboxEntry."Occurred At UTC";
        Payment."Latest Event At UTC" := InboxEntry."Occurred At UTC";
        Payment."Latest Logical Event Key" := InboxEntry."Logical Event Key";
        Payment."Origin Source" := InboxEntry.Source;
        Payment.Backfilled := Payment.Backfilled or Backfilled;

        if Payment.Status in [Payment.Status::PostedApplied, Payment.Status::ManuallyReconciled, Payment.Status::ManualJournalCreated] then begin
            Payment.Modify(true);
            exit;
        end;

        InvoiceMatcher.Match(Payment);
        Setup.GetRecordOnce();
        if Payment."Match Result" = Payment."Match Result"::UniqueExact then begin
            Payment.Status := Payment.Status::ReadyToPost;
            Payment.Modify(true);
            if Setup."Auto Post" then
                PaymentPoster.PostAndApply(Payment);
        end else begin
            Payment.Status := Payment.Status::Imported;
            Payment.Modify(true);
        end;
    end;

    procedure ApplyAdverseEvent(InboxEntry: Record "Adyen Inbox Entry")
    var
        Payment: Record "Imported Adyen Payment";
        PaymentReference: Code[50];
    begin
        if InboxEntry."Success Provided" and not InboxEntry.Success and
           not (UpperCase(InboxEntry."Message Type") in ['CAPTURE_FAILED', 'CAPTUREFAILED'])
        then
            exit;

        PaymentReference := GetOriginalPaymentReference(InboxEntry);
        if not Payment.Get(PaymentReference) then begin
            Payment.Init();
            Payment."PSP Reference" := PaymentReference;
            Payment."Merchant Reference" := InboxEntry."Merchant Reference";
            Payment."Shopper Reference" := InboxEntry."Shopper Reference";
            Payment."Payment Method" := InboxEntry."Payment Method";
            Payment."Currency Code" := InboxEntry."Currency Code";
            Payment.Amount := InboxEntry.Amount;
            Payment."Origin Source" := InboxEntry.Source;
            Payment.Insert(true);
        end;

        Payment."Latest Event At UTC" := InboxEntry."Occurred At UTC";
        Payment."Latest Logical Event Key" := InboxEntry."Logical Event Key";
        Payment.Status := Payment.Status::ReversalRequired;
        Payment."Exception Message" := CopyStr(
            StrSubstNo('%1 received for payment %2. Finance review is required.', InboxEntry."Message Type", PaymentReference),
            1, MaxStrLen(Payment."Exception Message"));
        Payment.Modify(true);
    end;

    procedure IsAdverseMessage(MessageType: Text): Boolean
    begin
        exit(UpperCase(MessageType) in [
            'CAPTURE_FAILED', 'CAPTUREFAILED', 'REFUND', 'REFUNDED', 'REFUND_FAILED', 'REFUNDFAILED',
            'CHARGEBACK', 'SECONDCHARGEBACK', 'SETTLEDREVERSED', 'SETTLED_REVERSED']);
    end;

    procedure GetOriginalPaymentReference(InboxEntry: Record "Adyen Inbox Entry"): Code[50]
    begin
        if InboxEntry."Original PSP Reference" <> '' then
            exit(CopyStr(InboxEntry."Original PSP Reference", 1, 50));
        exit(CopyStr(InboxEntry."PSP Reference", 1, 50));
    end;
}
