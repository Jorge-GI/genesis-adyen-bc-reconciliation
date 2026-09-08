codeunit 72039 "Adyen Journal Subscribers"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Line", 'OnAfterCustLedgEntryInsert', '', false, false)]
    local procedure OnAfterCustLedgEntryInsert(var CustLedgerEntry: Record "Cust. Ledger Entry"; GenJournalLine: Record "Gen. Journal Line"; DtldLedgEntryInserted: Boolean; PreviewMode: Boolean)
    var
        Payment: Record "Imported Adyen Payment";
    begin
        if PreviewMode or IsNullGuid(GenJournalLine."Adyen Payment ID") then
            exit;
        if CustLedgerEntry."Document Type" <> CustLedgerEntry."Document Type"::Payment then
            exit;
        Payment.SetRange(SystemId, GenJournalLine."Adyen Payment ID");
        if not Payment.FindFirst() then
            exit;

        Payment."Posted Payment Entry No." := CustLedgerEntry."Entry No.";
        if Payment.Status = Payment.Status::ManualJournalCreated then
            Payment.Status := Payment.Status::ManuallyReconciled;
        Payment."Exception Message" := '';
        Payment.Modify(true);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Gen. Journal Line", 'OnAfterDeleteEvent', '', false, false)]
    local procedure OnAfterDeleteJournalLine(var Rec: Record "Gen. Journal Line"; RunTrigger: Boolean)
    var
        Payment: Record "Imported Adyen Payment";
    begin
        if IsNullGuid(Rec."Adyen Payment ID") then
            exit;
        Payment.SetRange(SystemId, Rec."Adyen Payment ID");
        if not Payment.FindFirst() then
            exit;
        if (Payment.Status <> Payment.Status::ManualJournalCreated) or (Payment."Posted Payment Entry No." <> 0) then
            exit;

        Payment.Status := Payment."Status Before Manual";
        Payment."Manual Journal Template" := '';
        Payment."Manual Journal Batch" := '';
        Payment."Manual Journal Line No." := 0;
        Payment.Modify(true);
    end;
}
