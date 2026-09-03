namespace AdyenBridge.Application;

public sealed class AdyenOptions
{
    public const string SectionName = "Adyen";
    public string MerchantAccount { get; set; } = string.Empty;
    public string Environment { get; set; } = "test";
    public string[] HmacKeys { get; set; } = [];
    public int MaxBodyBytes { get; set; } = 1_048_576;
}

public sealed class IngressOptions
{
    public const string SectionName = "Ingress";
    public bool RequireEasyAuthPrincipal { get; set; } = true;
}

public sealed class ReportOptions
{
    public const string SectionName = "Reports";
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string[] AllowedHosts { get; set; } = ["ca-live.adyen.com", "ca-test.adyen.com"];
    public string Environment { get; set; } = "test";
    public string TimeZoneId { get; set; } = "UTC";
    public string Delimiter { get; set; } = ",";
    public int MaxFileBytes { get; set; } = 52_428_800;
    public string[] RelevantRecordTypes { get; set; } =
    [
        "SentForSettle", "CaptureFailed", "Cancelled", "Expired", "Refunded",
        "RefundFailed", "RefundedReversed", "Chargeback", "ChargebackReversed",
        "SecondChargeback", "SettledReversed"
    ];
}

