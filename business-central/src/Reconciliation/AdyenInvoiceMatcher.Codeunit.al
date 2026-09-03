codeunit 72032 "Adyen Invoice Matcher"
{
    procedure Match(var Payment: Record "Imported Adyen Payment")
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
        Customer: Record Customer;
        GeneralLedgerSetup: Record "General Ledger Setup";
        MethodPolicy: Record "Adyen Payment Method Policy";
        CandidateEntryNo: Integer;
        MatchCount: Integer;
        InvoiceCurrency: Code[10];
        PaymentCurrency: Code[10];
    begin
        Payment."Matched Invoice Entry No." := 0;
        Payment."Match Result" := Payment."Match Result"::NotRun;
        Payment."Exception Message" := '';

        if not MethodPolicy.Get(Payment."Payment Method") or not MethodPolicy."Enabled for Auto Post" then begin
            Payment."Match Result" := Payment."Match Result"::UnsupportedMethod;
            Payment."Exception Message" := StrSubstNo('Payment method %1 is not enabled for automatic posting.', Payment."Payment Method");
            exit;
        end;

        if Payment."Resolved Customer No." = '' then
            if StrLen(Payment."Shopper Reference") <= MaxStrLen(Payment."Resolved Customer No.") then
                Payment."Resolved Customer No." := CopyStr(Payment."Shopper Reference", 1, MaxStrLen(Payment."Resolved Customer No."));

        if not Customer.Get(Payment."Resolved Customer No.") then begin
            Payment."Match Result" := Payment."Match Result"::InvalidCustomer;
            Payment."Exception Message" := StrSubstNo('Shopper reference %1 does not resolve to a Business Central customer.', Payment."Shopper Reference");
            exit;
        end;
        if Customer.Blocked <> Customer.Blocked::" " then begin
            Payment."Match Result" := Payment."Match Result"::InvalidCustomer;
            Payment."Exception Message" := StrSubstNo('Customer %1 is blocked.', Customer."No.");
            exit;
        end;

        GeneralLedgerSetup.Get();
        PaymentCurrency := Payment."Currency Code";
        if PaymentCurrency = '' then
            PaymentCurrency := GeneralLedgerSetup."LCY Code";

        CustLedgerEntry.SetCurrentKey("Customer No.", Open, Positive, "Due Date", "Currency Code");
        CustLedgerEntry.SetRange("Customer No.", Customer."No.");
        CustLedgerEntry.SetRange("Document Type", CustLedgerEntry."Document Type"::Invoice);
        CustLedgerEntry.SetRange(Open, true);
        if CustLedgerEntry.FindSet() then
            repeat
                InvoiceCurrency := CustLedgerEntry."Currency Code";
                if InvoiceCurrency = '' then
                    InvoiceCurrency := GeneralLedgerSetup."LCY Code";
                if InvoiceCurrency = PaymentCurrency then begin
                    CustLedgerEntry.CalcFields("Remaining Amount");
                    if CustLedgerEntry."Remaining Amount" = Payment.Amount then begin
                        MatchCount += 1;
                        CandidateEntryNo := CustLedgerEntry."Entry No.";
                    end;
                end;
            until CustLedgerEntry.Next() = 0;

        case MatchCount of
            0:
                begin
                    Payment."Match Result" := Payment."Match Result"::None;
                    Payment."Exception Message" := 'No open invoice has the same currency and exact remaining amount.';
                end;
            1:
                begin
                    Payment."Match Result" := Payment."Match Result"::UniqueExact;
                    Payment."Matched Invoice Entry No." := CandidateEntryNo;
                end;
            else begin
                Payment."Match Result" := Payment."Match Result"::Multiple;
                Payment."Exception Message" := StrSubstNo('%1 open invoices have the same currency and exact remaining amount.', MatchCount);
            end;
        end;
    end;
}
