using System.Text.Json.Serialization;

namespace AdyenBridge.Contracts;

public enum InboundSource
{
    Webhook,
    Report
}

public enum AdyenEnvironment
{
    Test,
    Live
}

public enum ReportRunState
{
    Loading,
    Ready,
    Error
}

public sealed record InboundMessageV1
{
    public required string TransportId { get; init; }
    public required string LogicalEventKey { get; init; }
    public required InboundSource Source { get; init; }
    public required string MessageType { get; init; }
    public required DateTimeOffset OccurredAtUtc { get; init; }
    public required DateTimeOffset ReceivedAtUtc { get; init; }
    public required string PayloadHash { get; init; }
    public required string MerchantAccount { get; init; }
    public required AdyenEnvironment Environment { get; init; }
    public required string PspReference { get; init; }
    public string OriginalPspReference { get; init; } = string.Empty;
    public string MerchantReference { get; init; } = string.Empty;
    public string ShopperReference { get; init; } = string.Empty;
    public string PaymentMethod { get; init; } = string.Empty;
    public bool SuccessProvided { get; init; }
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public bool? Success { get; init; }
    public string CurrencyCode { get; init; } = string.Empty;
    public decimal Amount { get; init; }
    public string ReportRunId { get; init; } = string.Empty;
    public string ReportRowIdentity { get; init; } = string.Empty;
    public string RawArchiveReference { get; init; } = string.Empty;
}

public sealed record ReportRunV1
{
    public required string ExternalReportId { get; init; }
    public required string FileHash { get; init; }
    public required DateOnly ReportDate { get; init; }
    public required ReportRunState State { get; init; }
    public int TotalRowCount { get; init; }
    public int RelevantRowCount { get; init; }
    public int LoadedRowCount { get; init; }
    public required string ArchiveReference { get; init; }
    public string ErrorMessage { get; init; } = string.Empty;
}

public sealed record ReportRunUpdateV1
{
    public required ReportRunState State { get; init; }
    public required int TotalRowCount { get; init; }
    public required int RelevantRowCount { get; init; }
    public required int LoadedRowCount { get; init; }
    public string ErrorMessage { get; init; } = string.Empty;
}
