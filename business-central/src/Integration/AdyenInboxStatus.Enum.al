enum 72002 "Adyen Inbox Status"
{
    Extensible = false;

    value(0; Received) { Caption = 'Received'; }
    value(1; Processing) { Caption = 'Processing'; }
    value(2; Processed) { Caption = 'Processed'; }
    value(3; Error) { Caption = 'Error'; }
    value(4; Ignored) { Caption = 'Ignored'; }
}
