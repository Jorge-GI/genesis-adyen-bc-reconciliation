using AdyenBridge.Application;

namespace AdyenBridge.Application.Tests;

public sealed class ReportDateResolverTests
{
    [Fact]
    public void FromExternalReportIdReadsDailyReportDate()
    {
        var result = ReportDateResolver.FromExternalReportId(
            "payments_accounting_report_GenesisMerchant_2026_09_02_A1B2C3D4.csv");

        Assert.Equal(new DateOnly(2026, 9, 2), result);
    }

    [Fact]
    public void FromExternalReportIdRejectsNonDailyRange()
    {
        Assert.Throws<InvalidDataException>(() => ReportDateResolver.FromExternalReportId(
            "payments_accounting_report_filtered_2026_09_01_2026_09_03_A1B2C3D4.csv"));
    }
}
