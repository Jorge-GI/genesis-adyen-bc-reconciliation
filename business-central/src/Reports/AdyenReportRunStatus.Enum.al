enum 72006 "Adyen Report Run Status"
{
    Extensible = false;

    value(0; Requested) { Caption = 'Requested'; }
    value(1; Downloading) { Caption = 'Downloading'; }
    value(2; Loading) { Caption = 'Loading'; }
    value(3; Ready) { Caption = 'Ready'; }
    value(4; Processing) { Caption = 'Processing'; }
    value(5; Processed) { Caption = 'Processed'; }
    value(6; Error) { Caption = 'Error'; }
}
