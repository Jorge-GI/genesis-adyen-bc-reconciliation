using System.Globalization;
using System.Text.RegularExpressions;

namespace AdyenBridge.Application;

public static partial class ReportDateResolver
{
    [GeneratedRegex(@"(?<!\d)\d{4}_\d{2}_\d{2}(?!\d)", RegexOptions.CultureInvariant)]
    private static partial Regex DatePattern();

    public static DateOnly FromExternalReportId(string externalReportId)
    {
        var matches = DatePattern().Matches(externalReportId);
        if (matches.Count != 1 ||
            !DateOnly.TryParseExact(matches[0].Value, "yyyy_MM_dd", CultureInfo.InvariantCulture,
                DateTimeStyles.None, out var reportDate))
        {
            throw new InvalidDataException(
                $"Report '{externalReportId}' must be a daily Payment Accounting Report with one yyyy_MM_dd date in its filename.");
        }

        return reportDate;
    }
}
