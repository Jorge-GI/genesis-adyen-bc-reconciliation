codeunit 72048 "Adyen Webhook Worker"
{
    TableNo = "Adyen Webhook Request";

    trigger OnRun()
    var
        Intake: Codeunit "Adyen Webhook Intake";
    begin
        Rec.Status := Rec.Status::Processing;
        Rec.Modify(true);
        Intake.Normalize(Rec);
    end;
}
