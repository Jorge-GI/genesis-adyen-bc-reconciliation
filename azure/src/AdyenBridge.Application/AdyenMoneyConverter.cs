namespace AdyenBridge.Application;

public static class AdyenMoneyConverter
{
    private static readonly HashSet<string> ZeroDecimalCurrencies = new(StringComparer.OrdinalIgnoreCase)
    {
        "BIF", "CVE", "DJF", "GNF", "IDR", "JPY", "KMF", "KRW", "PYG", "RWF",
        "UGX", "VND", "VUV", "XAF", "XOF", "XPF"
    };

    private static readonly HashSet<string> ThreeDecimalCurrencies = new(StringComparer.OrdinalIgnoreCase)
    {
        "BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND"
    };

    public static decimal ToMajorUnits(long minorUnits, string currency)
    {
        var exponent = ZeroDecimalCurrencies.Contains(currency) ? 0 : ThreeDecimalCurrencies.Contains(currency) ? 3 : 2;
        var divisor = exponent switch { 0 => 1m, 3 => 1000m, _ => 100m };
        return minorUnits / divisor;
    }
}

