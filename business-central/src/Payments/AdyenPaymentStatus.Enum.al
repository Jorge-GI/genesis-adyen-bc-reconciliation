enum 72003 "Adyen Payment Status"
{
    Extensible = false;

    value(0; Imported) { Caption = 'Imported'; }
    value(1; ReadyToPost) { Caption = 'Ready to post'; }
    value(2; PostedApplied) { Caption = 'Posted and applied'; }
    value(3; ManualJournalCreated) { Caption = 'Manual journal created'; }
    value(4; ManuallyReconciled) { Caption = 'Manually reconciled'; }
    value(5; ReversalRequired) { Caption = 'Reversal required'; }
    value(6; Error) { Caption = 'Error'; }
    value(7; DataConflict) { Caption = 'Data conflict'; }
}
