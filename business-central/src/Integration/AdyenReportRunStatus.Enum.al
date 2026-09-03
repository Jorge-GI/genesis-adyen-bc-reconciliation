enum 72006 "Adyen Report Run Status"
{
    Extensible = false;

    value(0; Loading) { Caption = 'Loading'; }
    value(1; Ready) { Caption = 'Ready'; }
    value(2; Processing) { Caption = 'Processing'; }
    value(3; Processed) { Caption = 'Processed'; }
    value(4; Error) { Caption = 'Error'; }
}
