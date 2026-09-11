codeunit 72051 "Adyen Event Disposition"
{
    procedure ClearReason(var EventEntry: Record "Adyen Event Entry")
    begin
        EventEntry."Disposition Reason" := '';
    end;

    procedure MarkFailedAuthorisation(var EventEntry: Record "Adyen Event Entry")
    begin
        EventEntry.Status := EventEntry.Status::Ignored;
        if not EventEntry."Success Provided" then
            SetReason(EventEntry, GetMissingAuthorisationSuccessReason())
        else
            SetReason(EventEntry, GetUnsuccessfulAuthorisationReason());
    end;

    procedure MarkUnsupported(var EventEntry: Record "Adyen Event Entry")
    begin
        EventEntry.Status := EventEntry.Status::Ignored;
        SetReason(EventEntry, GetUnsupportedEventReason(EventEntry."Message Type"));
    end;

    procedure SetReason(var EventEntry: Record "Adyen Event Entry"; ReasonText: Text)
    begin
        EventEntry."Disposition Reason" := CopyStr(ReasonText, 1, MaxStrLen(EventEntry."Disposition Reason"));
    end;

    procedure GetUnsuccessfulAuthorisationReason(): Text[250]
    begin
        exit(CopyStr(UnsuccessfulAuthorisationLbl, 1, 250));
    end;

    procedure GetMissingAuthorisationSuccessReason(): Text[250]
    begin
        exit(CopyStr(MissingAuthorisationSuccessLbl, 1, 250));
    end;

    procedure GetUnsupportedEventReason(MessageType: Text): Text[250]
    begin
        exit(CopyStr(StrSubstNo(UnsupportedEventTypeLbl, NormalizeMessageType(MessageType)), 1, 250));
    end;

    procedure GetDuplicateLogicalEventReason(): Text[250]
    begin
        exit(CopyStr(DuplicateLogicalEventLbl, 1, 250));
    end;

    procedure GetOlderEventReason(): Text[250]
    begin
        exit(CopyStr(OlderEventLbl, 1, 250));
    end;

    procedure GetReversalReviewReason(): Text[250]
    begin
        exit(CopyStr(ReversalReviewLbl, 1, 250));
    end;

    procedure GetUnsuccessfulAdverseReason(MessageType: Text): Text[250]
    begin
        exit(CopyStr(StrSubstNo(UnsuccessfulAdverseLbl, NormalizeMessageType(MessageType)), 1, 250));
    end;

    procedure NormalizeMessageType(MessageType: Text): Text
    begin
        exit(UpperCase(DelChr(MessageType, '=', '_- ')));
    end;

    var
        UnsuccessfulAuthorisationLbl: Label 'AUTHORISATION was ignored because Adyen reported success as false.';
        MissingAuthorisationSuccessLbl: Label 'AUTHORISATION was ignored because the success value was missing or invalid.';
        UnsupportedEventTypeLbl: Label 'Event type "%1" is not supported and was ignored.', Comment = '%1 = normalized Adyen event type';
        DuplicateLogicalEventLbl: Label 'The logical event was already applied; no payment state change was needed.';
        OlderEventLbl: Label 'The event is older than the payment''s latest retained event; no payment state change was made.';
        ReversalReviewLbl: Label 'The payment already requires reversal review; the positive event made no payment state change.';
        UnsuccessfulAdverseLbl: Label 'Unsuccessful %1 event required no payment state change.', Comment = '%1 = normalized Adyen event type';
}
