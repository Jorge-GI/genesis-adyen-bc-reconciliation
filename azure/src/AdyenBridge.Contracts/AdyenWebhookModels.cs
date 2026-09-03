using System.Text.Json.Serialization;

namespace AdyenBridge.Contracts;

public sealed record AdyenWebhookPayload
{
    [JsonPropertyName("live")]
    public required string Live { get; init; }

    [JsonPropertyName("notificationItems")]
    public required IReadOnlyList<AdyenNotificationContainer> NotificationItems { get; init; }
}

public sealed record AdyenNotificationContainer
{
    [JsonPropertyName("NotificationRequestItem")]
    public required AdyenNotificationItem Item { get; init; }
}

public sealed record AdyenNotificationItem
{
    [JsonPropertyName("additionalData")]
    public IReadOnlyDictionary<string, string> AdditionalData { get; init; } = new Dictionary<string, string>();

    [JsonPropertyName("amount")]
    public required AdyenAmount Amount { get; init; }

    [JsonPropertyName("eventCode")]
    public required string EventCode { get; init; }

    [JsonPropertyName("eventDate")]
    public required DateTimeOffset EventDate { get; init; }

    [JsonPropertyName("merchantAccountCode")]
    public required string MerchantAccountCode { get; init; }

    [JsonPropertyName("merchantReference")]
    public string MerchantReference { get; init; } = string.Empty;

    [JsonPropertyName("originalReference")]
    public string OriginalReference { get; init; } = string.Empty;

    [JsonPropertyName("paymentMethod")]
    public string PaymentMethod { get; init; } = string.Empty;

    [JsonPropertyName("pspReference")]
    public required string PspReference { get; init; }

    [JsonPropertyName("reason")]
    public string Reason { get; init; } = string.Empty;

    [JsonPropertyName("success")]
    public required string Success { get; init; }
}

public sealed record AdyenAmount
{
    [JsonPropertyName("currency")]
    public required string Currency { get; init; }

    [JsonPropertyName("value")]
    public long Value { get; init; }
}

