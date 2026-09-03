using System.Globalization;
using System.Text;
using AdyenBridge.Contracts;
using CsvHelper;
using CsvHelper.Configuration;

namespace AdyenBridge.Application;

public sealed record ParsedReport(int TotalRows, IReadOnlyList<InboundMessageV1> RelevantRows);

public sealed class PaymentAccountingReportParser
{
    private static readonly string[] RequiredHeaders =
    [
        "Merchant Account", "Psp Reference", "Merchant Reference", "Payment Currency",
        "Captured (PC)", "Record Type", "Booking Date", "Shopper Reference"
    ];

    public ParsedReport Parse(byte[] content, string reportId, string fileHash, string archiveReference, ReportOptions options, DateTimeOffset receivedAtUtc)
    {
        using var stream = new MemoryStream(content, writable: false);
        using var reader = new StreamReader(stream, Encoding.UTF8, detectEncodingFromByteOrderMarks: true);
        var configuration = new CsvConfiguration(CultureInfo.InvariantCulture)
        {
            Delimiter = options.Delimiter,
            BadDataFound = null,
            MissingFieldFound = null,
            TrimOptions = TrimOptions.Trim
        };
        using var csv = new CsvReader(reader, configuration);

        if (!csv.Read() || !csv.ReadHeader())
        {
            throw new InvalidDataException("The report has no header row.");
        }

        var headers = new HashSet<string>(csv.HeaderRecord ?? [], StringComparer.OrdinalIgnoreCase);
        var missing = RequiredHeaders.Where(header => !headers.Contains(header)).ToArray();
        if (missing.Length > 0)
        {
            throw new InvalidDataException($"The report is missing required columns: {string.Join(", ", missing)}.");
        }

        var relevantTypes = new HashSet<string>(options.RelevantRecordTypes, StringComparer.OrdinalIgnoreCase);
        var rows = new List<InboundMessageV1>();
        var totalRows = 0;
        while (csv.Read())
        {
            totalRows++;
            var recordType = csv.GetField("Record Type") ?? string.Empty;
            if (!relevantTypes.Contains(recordType))
            {
                continue;
            }

            var merchant = csv.GetField("Merchant Account") ?? string.Empty;
            var paymentPspReference = csv.GetField("Psp Reference") ?? string.Empty;
            var modificationReference = TryGet(csv, "Modification Psp Reference");
            var currency = csv.GetField("Payment Currency") ?? string.Empty;
            var capturedAmount = ParseDecimal(csv.GetField("Captured (PC)"), "Captured (PC)");
            var occurredAt = ParseBookingTime(csv.GetField("Booking Date"), TryGet(csv, "Booking Time"), options.TimeZoneId);
            var canonicalRow = string.Join('|', merchant, paymentPspReference, modificationReference, recordType,
                occurredAt.UtcDateTime.ToString("O"), currency, capturedAmount.ToString(CultureInfo.InvariantCulture));
            var rowIdentity = Hashing.Sha256(canonicalRow);

            rows.Add(new InboundMessageV1
            {
                TransportId = Hashing.Sha256(string.Join('|', fileHash, totalRows, rowIdentity)),
                LogicalEventKey = Hashing.Sha256(string.Join('|', merchant, recordType, paymentPspReference, modificationReference)),
                Source = InboundSource.Report,
                MessageType = recordType,
                OccurredAtUtc = occurredAt,
                ReceivedAtUtc = receivedAtUtc,
                PayloadHash = rowIdentity,
                MerchantAccount = merchant,
                Environment = string.Equals(options.Environment, "live", StringComparison.OrdinalIgnoreCase)
                    ? AdyenEnvironment.Live : AdyenEnvironment.Test,
                PspReference = string.IsNullOrWhiteSpace(modificationReference) ? paymentPspReference : modificationReference,
                OriginalPspReference = paymentPspReference,
                MerchantReference = csv.GetField("Merchant Reference") ?? string.Empty,
                ShopperReference = csv.GetField("Shopper Reference") ?? string.Empty,
                PaymentMethod = TryGet(csv, "Payment Method") is { Length: > 0 } paymentMethod
                    ? paymentMethod : TryGet(csv, "Payment Method Variant"),
                SuccessProvided = true,
                Success = true,
                CurrencyCode = currency,
                Amount = Math.Abs(capturedAmount),
                ReportRunId = reportId,
                ReportRowIdentity = rowIdentity,
                RawArchiveReference = archiveReference
            });
        }

        return new ParsedReport(totalRows, rows);
    }

    private static string TryGet(CsvReader csv, string name) =>
        csv.TryGetField<string>(name, out var value) ? value ?? string.Empty : string.Empty;

    private static decimal ParseDecimal(string? value, string fieldName) =>
        decimal.TryParse(value, NumberStyles.Number | NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out var result)
            ? result
            : throw new InvalidDataException($"The {fieldName} value '{value}' is invalid.");

    private static DateTimeOffset ParseBookingTime(string? date, string time, string timeZoneId)
    {
        var combined = string.IsNullOrWhiteSpace(time) ? date : $"{date} {time}";
        if (!DateTime.TryParse(combined, CultureInfo.InvariantCulture, DateTimeStyles.AllowWhiteSpaces, out var localTime))
        {
            throw new InvalidDataException($"The report booking time '{combined}' is invalid.");
        }

        var zone = TimeZoneInfo.FindSystemTimeZoneById(timeZoneId);
        var unspecified = DateTime.SpecifyKind(localTime, DateTimeKind.Unspecified);
        return new DateTimeOffset(TimeZoneInfo.ConvertTimeToUtc(unspecified, zone));
    }
}
