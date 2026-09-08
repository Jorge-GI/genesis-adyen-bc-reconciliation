codeunit 72032 "Adyen Cryptography"
{
    procedure GenerateSha256(Input: Text): Code[64]
    var
        CryptographyManagement: Codeunit "Cryptography Management";
    begin
        exit(CopyStr(LowerCase(CryptographyManagement.GenerateHash(Input, 2)), 1, 64));
    end;

    procedure GenerateStreamHash(Input: InStream): Code[64]
    var
        CryptographyManagement: Codeunit "Cryptography Management";
    begin
        exit(CopyStr(CryptographyManagement.GenerateHash(Input, 2), 1, 64));
    end;

    [NonDebuggable]
    procedure HexToBase64(HexKey: Text): Text
    var
        Base64Convert: Codeunit "Base64 Convert";
        TempBlob: Codeunit "Temp Blob";
        KeyInStream: InStream;
        KeyOutStream: OutStream;
        ByteValue: Byte;
        Index: Integer;
    begin
        HexKey := LowerCase(DelChr(HexKey, '=', ' '));
        if (StrLen(HexKey) <> 64) then
            Error('An Adyen HMAC key must contain exactly 64 hexadecimal characters.');

        TempBlob.CreateOutStream(KeyOutStream);
        Index := 1;
        while Index <= StrLen(HexKey) do begin
            ByteValue := HexDigit(CopyStr(HexKey, Index, 1)) * 16 + HexDigit(CopyStr(HexKey, Index + 1, 1));
            KeyOutStream.Write(ByteValue);
            Index += 2;
        end;
        TempBlob.CreateInStream(KeyInStream);
        exit(Base64Convert.ToBase64(KeyInStream));
    end;

    procedure VerifyNotification(Item: JsonObject): Boolean
    var
        Credentials: Codeunit "Adyen Credentials";
        CurrentKey: SecretText;
        PreviousKey: SecretText;
    begin
        if Credentials.GetCurrentHmacKey(CurrentKey) and VerifyWithBase64Key(Item, CurrentKey) then
            exit(true);
        if Credentials.GetPreviousHmacKey(PreviousKey) and VerifyWithBase64Key(Item, PreviousKey) then
            exit(true);
        exit(false);
    end;

    [NonDebuggable]
    procedure VerifyWithHexKey(Item: JsonObject; HexKey: Text): Boolean
    var
        Base64Key: SecretText;
    begin
        Base64Key := HexToBase64(HexKey);
        exit(VerifyWithBase64Key(Item, Base64Key));
    end;

    [NonDebuggable]
    local procedure VerifyWithBase64Key(Item: JsonObject; Base64Key: SecretText): Boolean
    var
        CryptographyManagement: Codeunit "Cryptography Management";
        Signature: Text;
        SigningValue: Text;
    begin
        Signature := GetAdditionalDataValue(Item, 'hmacSignature');
        if Signature = '' then
            exit(false);
        SigningValue := BuildSigningValue(Item);
        exit(CryptographyManagement.GenerateBase64KeyedHashAsBase64String(SigningValue, Base64Key, 2) = Signature);
    end;

    procedure BuildSigningValue(Item: JsonObject): Text
    var
        AmountObject: JsonObject;
    begin
        AmountObject := GetObject(Item, 'amount');
        exit(
            Escape(GetText(Item, 'pspReference')) + ':' +
            Escape(GetOptionalText(Item, 'originalReference')) + ':' +
            Escape(GetText(Item, 'merchantAccountCode')) + ':' +
            Escape(GetOptionalText(Item, 'merchantReference')) + ':' +
            GetText(AmountObject, 'value') + ':' +
            Escape(GetText(AmountObject, 'currency')) + ':' +
            Escape(GetText(Item, 'eventCode')) + ':' +
            Escape(GetText(Item, 'success')));
    end;

    local procedure Escape(Value: Text): Text
    begin
        exit(Value.Replace('\', '\\').Replace(':', '\:'));
    end;

    local procedure HexDigit(Value: Text[1]): Integer
    begin
        case Value of
            '0' .. '9':
                exit(Value[1] - '0');
            'a' .. 'f':
                exit(Value[1] - 'a' + 10);
        end;
        Error('The HMAC key contains a non-hexadecimal character.');
    end;

    local procedure GetAdditionalDataValue(Item: JsonObject; Name: Text): Text
    var
        AdditionalData: JsonObject;
        Token: JsonToken;
    begin
        if not Item.Get('additionalData', Token) or not Token.IsObject() then
            exit('');
        AdditionalData := Token.AsObject();
        exit(GetOptionalText(AdditionalData, Name));
    end;

    local procedure GetObject(Object: JsonObject; Name: Text): JsonObject
    var
        Token: JsonToken;
    begin
        if not Object.Get(Name, Token) or not Token.IsObject() then
            Error('The webhook property %1 must be an object.', Name);
        exit(Token.AsObject());
    end;

    local procedure GetText(Object: JsonObject; Name: Text): Text
    var
        Value: Text;
    begin
        Value := GetOptionalText(Object, Name);
        if Value = '' then
            Error('The webhook property %1 is required.', Name);
        exit(Value);
    end;

    local procedure GetOptionalText(Object: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        if not Object.Get(Name, Token) or not Token.IsValue() then
            exit('');
        exit(Token.AsValue().AsText());
    end;
}
