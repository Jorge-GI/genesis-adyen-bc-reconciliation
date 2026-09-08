codeunit 72033 "Adyen Money"
{
    procedure ToMajorUnits(MinorUnits: BigInteger; CurrencyCode: Code[10]): Decimal
    var
        Divisor: Decimal;
    begin
        if IsZeroDecimal(CurrencyCode) then
            Divisor := 1
        else
            if IsThreeDecimal(CurrencyCode) then
                Divisor := 1000
            else
                Divisor := 100;
        exit(MinorUnits / Divisor);
    end;

    local procedure IsZeroDecimal(CurrencyCode: Code[10]): Boolean
    begin
        exit(UpperCase(CurrencyCode) in [
            'BIF', 'CVE', 'DJF', 'GNF', 'IDR', 'JPY', 'KMF', 'KRW', 'PYG', 'RWF',
            'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF']);
    end;

    local procedure IsThreeDecimal(CurrencyCode: Code[10]): Boolean
    begin
        exit(UpperCase(CurrencyCode) in ['BHD', 'IQD', 'JOD', 'KWD', 'LYD', 'OMR', 'TND']);
    end;
}
