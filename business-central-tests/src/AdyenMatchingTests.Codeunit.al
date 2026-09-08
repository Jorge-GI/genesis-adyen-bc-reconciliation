codeunit 72155 "Adyen Matching Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure UnsupportedMissingAndBlockedCustomersAreRejected()
    var
        Customer: Record Customer;
        Payment: Record "Imported Adyen Payment";
        Matcher: Codeunit "Adyen Invoice Matcher";
    begin
        BuildPayment(Payment, 'UNKNOWN', 'not-enabled');
        Matcher.Match(Payment);
        AssertTrue(Payment."Match Result" = Payment."Match Result"::UnsupportedMethod, 'Unsupported methods must stop automatic matching.');

        EnableMethod('scheme');
        BuildPayment(Payment, 'MISSING-CUSTOMER', 'scheme');
        Matcher.Match(Payment);
        AssertTrue(Payment."Match Result" = Payment."Match Result"::InvalidCustomer, 'A missing customer must be rejected.');

        InsertCustomer(Customer, 'ADY-BLOCKED');
        Customer.Blocked := Customer.Blocked::All;
        Customer.Modify(false);
        BuildPayment(Payment, Customer."No.", 'scheme');
        Matcher.Match(Payment);
        AssertTrue(Payment."Match Result" = Payment."Match Result"::InvalidCustomer, 'A blocked customer must be rejected.');
    end;

    [Test]
    procedure NoUniqueAndMultipleExactInvoicesAreDistinguished()
    var
        Customer: Record Customer;
        Payment: Record "Imported Adyen Payment";
        Matcher: Codeunit "Adyen Invoice Matcher";
    begin
        EnableMethod('scheme');
        InsertCustomer(Customer, 'ADY-MATCH');
        BuildPayment(Payment, Customer."No.", 'scheme');
        Payment.Amount := 100;
        Payment."Currency Code" := '';

        Matcher.Match(Payment);
        AssertTrue(Payment."Match Result" = Payment."Match Result"::None, 'No invoice must produce no match.');

        InsertOpenInvoice(Customer."No.", 'ADY-INV-1', '', 100);
        Matcher.Match(Payment);
        AssertTrue(Payment."Match Result" = Payment."Match Result"::UniqueExact, 'One exact invoice must produce a unique match.');

        Payment.Amount := 99;
        Matcher.Match(Payment);
        AssertTrue(Payment."Match Result" = Payment."Match Result"::None, 'A partial amount must not match.');
        Payment.Amount := 101;
        Matcher.Match(Payment);
        AssertTrue(Payment."Match Result" = Payment."Match Result"::None, 'An overpayment must not match.');

        Payment.Amount := 100;
        InsertOpenInvoice(Customer."No.", 'ADY-INV-2', '', 100);
        Matcher.Match(Payment);
        AssertTrue(Payment."Match Result" = Payment."Match Result"::Multiple, 'Two exact invoices must require manual review.');
    end;

    [Test]
    procedure CurrencyMustMatchAfterLcyNormalization()
    var
        Customer: Record Customer;
        Payment: Record "Imported Adyen Payment";
        Matcher: Codeunit "Adyen Invoice Matcher";
    begin
        EnableMethod('scheme');
        InsertCustomer(Customer, 'ADY-CURRENCY');
        InsertOpenInvoice(Customer."No.", 'ADY-INV-LCY', '', 100);
        BuildPayment(Payment, Customer."No.", 'scheme');
        Payment.Amount := 100;
        Payment."Currency Code" := 'USD';
        Matcher.Match(Payment);
        AssertTrue(Payment."Match Result" = Payment."Match Result"::None, 'Foreign currency must not match an LCY invoice.');

        Payment."Currency Code" := '';
        Matcher.Match(Payment);
        AssertTrue(Payment."Match Result" = Payment."Match Result"::UniqueExact, 'Blank payment currency must normalize to LCY.');
    end;

    local procedure EnableMethod(PaymentMethod: Code[50])
    var
        MethodPolicy: Record "Adyen Payment Method Policy";
    begin
        if MethodPolicy.Get(PaymentMethod) then
            MethodPolicy.Delete(false);
        MethodPolicy.Init();
        MethodPolicy."Payment Method" := PaymentMethod;
        MethodPolicy."Enabled for Auto Post" := true;
        MethodPolicy.Insert(false);
    end;

    local procedure InsertCustomer(var Customer: Record Customer; CustomerNo: Code[20])
    begin
        if Customer.Get(CustomerNo) then
            Customer.Delete(false);
        Customer.Init();
        Customer."No." := CustomerNo;
        Customer.Name := CustomerNo;
        Customer.Insert(false);
    end;

    local procedure BuildPayment(var Payment: Record "Imported Adyen Payment"; ShopperReference: Text; PaymentMethod: Code[50])
    begin
        Clear(Payment);
        Payment.Init();
        Payment."Shopper Reference" := ShopperReference;
        Payment."Payment Method" := PaymentMethod;
        Payment.Amount := 100;
    end;

    local procedure InsertOpenInvoice(CustomerNo: Code[20]; DocumentNo: Code[20]; CurrencyCode: Code[10]; RemainingAmount: Decimal)
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
        DetailedCustLedgerEntry: Record "Detailed Cust. Ledg. Entry";
        CustEntryNo: Integer;
        DetailEntryNo: Integer;
    begin
        CustLedgerEntry.LockTable();
        if CustLedgerEntry.FindLast() then
            CustEntryNo := CustLedgerEntry."Entry No." + 1000
        else
            CustEntryNo := 990000000;
        CustLedgerEntry.Init();
        CustLedgerEntry."Entry No." := CustEntryNo;
        CustLedgerEntry."Customer No." := CustomerNo;
        CustLedgerEntry."Posting Date" := WorkDate();
        CustLedgerEntry."Document Type" := CustLedgerEntry."Document Type"::Invoice;
        CustLedgerEntry."Document No." := DocumentNo;
        CustLedgerEntry."Currency Code" := CurrencyCode;
        CustLedgerEntry.Open := true;
        CustLedgerEntry.Positive := true;
        CustLedgerEntry.Insert(false);

        DetailedCustLedgerEntry.LockTable();
        if DetailedCustLedgerEntry.FindLast() then
            DetailEntryNo := DetailedCustLedgerEntry."Entry No." + 1000
        else
            DetailEntryNo := 990000000;
        DetailedCustLedgerEntry.Init();
        DetailedCustLedgerEntry."Entry No." := DetailEntryNo;
        DetailedCustLedgerEntry."Cust. Ledger Entry No." := CustLedgerEntry."Entry No.";
        DetailedCustLedgerEntry."Entry Type" := DetailedCustLedgerEntry."Entry Type"::"Initial Entry";
        DetailedCustLedgerEntry."Posting Date" := WorkDate();
        DetailedCustLedgerEntry."Customer No." := CustomerNo;
        DetailedCustLedgerEntry."Currency Code" := CurrencyCode;
        DetailedCustLedgerEntry.Amount := RemainingAmount;
        DetailedCustLedgerEntry."Amount (LCY)" := RemainingAmount;
        DetailedCustLedgerEntry.Insert(false);
    end;

    local procedure AssertTrue(Actual: Boolean; FailureMessage: Text)
    begin
        if not Actual then
            Error(FailureMessage);
    end;
}
