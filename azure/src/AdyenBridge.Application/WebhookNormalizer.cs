using System.Text.Json;
using AdyenBridge.Contracts;

namespace AdyenBridge.Application;

public sealed class WebhookNormalizer
{
    public AdyenNotificationItem Deserialize(RawWebhookMessage raw) =>
        JsonSerializer.Deserialize<AdyenNotificationItem>(raw.NotificationJson, ContractJson.SerializerOptions)
        ?? throw new JsonException("The queued notification is empty.");

    public InboundMessageV1 Normalize(RawWebhookMessage raw, AdyenNotificationItem item, string archiveReference)
    {
        var success = bool.TryParse(item.Success, out var parsedSuccess) ? parsedSuccess : (bool?)null;
        return new InboundMessageV1
        {
            TransportId = raw.TransportId,
            LogicalEventKey = raw.LogicalEventKey,
            Source = InboundSource.Webhook,
            MessageType = item.EventCode,
            OccurredAtUtc = item.EventDate,
            ReceivedAtUtc = raw.ReceivedAtUtc,
            PayloadHash = raw.PayloadHash,
            MerchantAccount = item.MerchantAccountCode,
            Environment = raw.Live ? AdyenEnvironment.Live : AdyenEnvironment.Test,
            PspReference = item.PspReference,
            OriginalPspReference = item.OriginalReference,
            MerchantReference = item.MerchantReference,
            ShopperReference = WebhookParser.GetShopperReference(item),
            PaymentMethod = item.PaymentMethod,
            SuccessProvided = success.HasValue,
            Success = success,
            CurrencyCode = item.Amount.Currency,
            Amount = Math.Abs(AdyenMoneyConverter.ToMajorUnits(item.Amount.Value, item.Amount.Currency)),
            RawArchiveReference = archiveReference
        };
    }
}
