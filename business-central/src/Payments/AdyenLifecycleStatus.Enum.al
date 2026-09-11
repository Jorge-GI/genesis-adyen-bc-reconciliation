enum 72007 "Adyen Lifecycle Status"
{
    Extensible = false;

    value(0; Unknown) { Caption = 'Unknown'; }
    value(1; Authorised) { Caption = 'Authorised'; }
    value(2; SentForSettle) { Caption = 'Sent for settle'; }
    value(3; Settled) { Caption = 'Settled'; }
    value(4; Cancelled) { Caption = 'Cancelled'; }
    value(5; Expired) { Caption = 'Expired'; }
    value(6; CaptureFailed) { Caption = 'Capture failed'; }
    value(7; Refunded) { Caption = 'Refunded'; }
    value(8; RefundFailed) { Caption = 'Refund failed'; }
    value(9; RefundedReversed) { Caption = 'Refunded reversed'; }
    value(10; Chargeback) { Caption = 'Chargeback'; }
    value(11; ChargebackReversed) { Caption = 'Chargeback reversed'; }
    value(12; SecondChargeback) { Caption = 'Second chargeback'; }
    value(13; SettledReversed) { Caption = 'Settled reversed'; }
}
