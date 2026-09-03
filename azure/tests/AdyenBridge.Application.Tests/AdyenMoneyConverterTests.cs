using AdyenBridge.Application;

namespace AdyenBridge.Application.Tests;

public sealed class AdyenMoneyConverterTests
{
    [Theory]
    [InlineData(12345, "EUR", 123.45)]
    [InlineData(12345, "ISK", 123.45)]
    [InlineData(12345, "JPY", 12345)]
    [InlineData(12345, "IDR", 12345)]
    [InlineData(12345, "KWD", 12.345)]
    public void ToMajorUnitsUsesAdyenCurrencyExponent(long value, string currency, decimal expected)
    {
        Assert.Equal(expected, AdyenMoneyConverter.ToMajorUnits(value, currency));
    }
}
