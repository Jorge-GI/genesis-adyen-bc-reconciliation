namespace AdyenBridge.Contracts;

public sealed record RawWebhookMessage
{
    public required string TransportId { get; init; }
    public required string LogicalEventKey { get; init; }
    public required DateTimeOffset ReceivedAtUtc { get; init; }
    public required bool Live { get; init; }
    public required string RawPayloadJson { get; init; }
    public required string NotificationJson { get; init; }
    public required string PayloadHash { get; init; }
}

public sealed record ReportJobMessage
{
    public required string TransportId { get; init; }
    public required string ExternalReportId { get; init; }
    public required Uri DownloadUri { get; init; }
    public required DateTimeOffset OccurredAtUtc { get; init; }
    public required string MerchantAccount { get; init; }
    public required bool Live { get; init; }
    public required string SourceArchiveReference { get; init; }
}
