codeunit 72150 "Adyen Crypto Money Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure HmacVectorAndEscapingAreAccepted()
    var
        Credentials: Codeunit "Adyen Credentials";
        Crypto: Codeunit "Adyen Cryptography";
        Item: JsonObject;
    begin
        Credentials.ClearPreviousHmac();
        Credentials.SetCurrentHmacHex(HmacKey());
        Item := CreateSignedItem('LkSKgyRPvceAQl8+bWrDIVTejATF56CjvObTPC9CNDw=', 12345);
        AssertEqualText(
            '8831234567890123::GenesisMerchant:ORDER\:1\\A:12345:EUR:AUTHORISATION:true',
            Crypto.BuildSigningValue(Item), 'The canonical Adyen signing value is incorrect.');
        AssertTrue(Crypto.VerifyNotification(Item), 'The published HMAC vector was rejected.');
        Credentials.ClearCurrentHmac();
    end;

    [Test]
    procedure ChangedAmountAndMalformedSignatureAreRejected()
    var
        Credentials: Codeunit "Adyen Credentials";
        Crypto: Codeunit "Adyen Cryptography";
        Item: JsonObject;
    begin
        Credentials.ClearPreviousHmac();
        Credentials.SetCurrentHmacHex(HmacKey());
        Item := CreateSignedItem('LkSKgyRPvceAQl8+bWrDIVTejATF56CjvObTPC9CNDw=', 12346);
        AssertFalse(Crypto.VerifyNotification(Item), 'A changed amount must invalidate the signature.');

        Item := CreateSignedItem('not-base64', 12345);
        AssertFalse(Crypto.VerifyNotification(Item), 'A malformed signature must be rejected.');
        Credentials.ClearCurrentHmac();
    end;

    [Test]
    procedure PreviousKeyRemainsValidDuringRotation()
    var
        Credentials: Codeunit "Adyen Credentials";
        Crypto: Codeunit "Adyen Cryptography";
        Item: JsonObject;
    begin
        Credentials.ClearPreviousHmac();
        Credentials.SetCurrentHmacHex(HmacKey());
        Credentials.RotateCurrentHmacHex('111122223333444455556666777788889999aaaabbbbccccddddeeeeffff0000');
        Item := CreateSignedItem('LkSKgyRPvceAQl8+bWrDIVTejATF56CjvObTPC9CNDw=', 12345);

        AssertTrue(Crypto.VerifyNotification(Item), 'The previous HMAC key was not accepted after rotation.');
        Credentials.ClearPreviousHmac();
    end;

    [Test]
    procedure InvalidHexKeyIsRejected()
    var
        Crypto: Codeunit "Adyen Cryptography";
    begin
        asserterror Crypto.HexToBase64('not-a-hex-key');
    end;

    [Test]
    procedure MinorUnitsUseAdyenCurrencyExponents()
    var
        Money: Codeunit "Adyen Money";
    begin
        AssertEqualDecimal(123.45, Money.ToMajorUnits(12345, 'EUR'), 'EUR must use two decimal places.');
        AssertEqualDecimal(123.45, Money.ToMajorUnits(12345, 'ISK'), 'ISK must use Adyen''s two decimal places.');
        AssertEqualDecimal(12345, Money.ToMajorUnits(12345, 'JPY'), 'JPY must use zero decimal places.');
        AssertEqualDecimal(12345, Money.ToMajorUnits(12345, 'IDR'), 'IDR must use Adyen''s zero decimal places.');
        AssertEqualDecimal(12.345, Money.ToMajorUnits(12345, 'KWD'), 'KWD must use three decimal places.');
    end;

    local procedure CreateSignedItem(Signature: Text; AmountValue: BigInteger): JsonObject
    var
        Item: JsonObject;
        Amount: JsonObject;
        AdditionalData: JsonObject;
    begin
        Amount.Add('currency', 'EUR');
        Amount.Add('value', AmountValue);
        AdditionalData.Add('hmacSignature', Signature);
        Item.Add('additionalData', AdditionalData);
        Item.Add('amount', Amount);
        Item.Add('eventCode', 'AUTHORISATION');
        Item.Add('eventDate', '2026-09-03T10:00:00Z');
        Item.Add('merchantAccountCode', 'GenesisMerchant');
        Item.Add('merchantReference', 'ORDER:1\A');
        Item.Add('pspReference', '8831234567890123');
        Item.Add('success', 'true');
        exit(Item);
    end;

    local procedure HmacKey(): Text
    begin
        exit('00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff');
    end;

    local procedure AssertTrue(Actual: Boolean; FailureMessage: Text)
    begin
        if not Actual then
            Error(FailureMessage);
    end;

    local procedure AssertFalse(Actual: Boolean; FailureMessage: Text)
    begin
        if Actual then
            Error(FailureMessage);
    end;

    local procedure AssertEqualText(Expected: Text; Actual: Text; FailureMessage: Text)
    begin
        if Expected <> Actual then
            Error('%1 Expected %2, actual %3.', FailureMessage, Expected, Actual);
    end;

    local procedure AssertEqualDecimal(Expected: Decimal; Actual: Decimal; FailureMessage: Text)
    begin
        if Expected <> Actual then
            Error('%1 Expected %2, actual %3.', FailureMessage, Expected, Actual);
    end;
}
