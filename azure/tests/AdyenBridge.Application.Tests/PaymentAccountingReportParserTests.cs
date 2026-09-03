using System.Text;
using AdyenBridge.Application;

namespace AdyenBridge.Application.Tests;

public sealed class PaymentAccountingReportParserTests
{
    [Fact]
    public void ParseIgnoresUnrelatedRowsAndNormalizesSentForSettle()
    {
        const string csv = "Merchant Account,Psp Reference,Merchant Reference,Payment Currency,Captured (PC),Record Type,Booking Date,Booking Time,Shopper Reference,Payment Method Variant,Modification Psp Reference\n" +
                           "GenesisMerchant,8831234567890123,ORDER-1,EUR,123.45,Authorised,2026-09-03,10:00:00,C10000,visa,\n" +
                           "GenesisMerchant,8831234567890123,ORDER-1,EUR,-123.45,SentForSettle,2026-09-03,10:01:00,C10000,visa,9911234567890123\n";
        var parser = new PaymentAccountingReportParser();
        var options = new ReportOptions { Environment = "test", TimeZoneId = "UTC" };

        var result = parser.Parse(Encoding.UTF8.GetBytes(csv), "report.csv", "abc", "https://blob/report.csv",
            options, DateTimeOffset.Parse("2026-09-04T08:00:00Z", System.Globalization.CultureInfo.InvariantCulture));

        Assert.Equal(2, result.TotalRows);
        var row = Assert.Single(result.RelevantRows);
        Assert.Equal("SentForSettle", row.MessageType);
        Assert.Equal("8831234567890123", row.OriginalPspReference);
        Assert.Equal("9911234567890123", row.PspReference);
        Assert.Equal(123.45m, row.Amount);
        Assert.Equal("C10000", row.ShopperReference);
    }

    [Fact]
    public void ParseAllowsReorderedAndAdditionalColumns()
    {
        const string csv = "Extra,Record Type,Booking Date,Captured (PC),Payment Currency,Shopper Reference,Merchant Reference,Psp Reference,Merchant Account\n" +
                           "ignored,SentForSettle,2026-09-03,10.00,EUR,C10000,ORDER-1,8831234567890123,GenesisMerchant\n";
        var parser = new PaymentAccountingReportParser();

        var result = parser.Parse(Encoding.UTF8.GetBytes(csv), "report.csv", "abc", "https://blob/report.csv",
            new ReportOptions { Environment = "test", TimeZoneId = "UTC" }, DateTimeOffset.UtcNow);

        var row = Assert.Single(result.RelevantRows);
        Assert.Equal("8831234567890123", row.OriginalPspReference);
        Assert.Equal(10m, row.Amount);
    }

    [Fact]
    public void ParseRejectsMissingRequiredColumn()
    {
        const string csv = "Merchant Account,Psp Reference,Merchant Reference,Payment Currency,Captured (PC),Record Type,Booking Date\n";
        var parser = new PaymentAccountingReportParser();

        var exception = Assert.Throws<InvalidDataException>(() => parser.Parse(
            Encoding.UTF8.GetBytes(csv), "report.csv", "abc", "https://blob/report.csv",
            new ReportOptions(), DateTimeOffset.UtcNow));

        Assert.Contains("Shopper Reference", exception.Message, StringComparison.Ordinal);
    }
}
