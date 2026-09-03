using System.Security;
using System.Text.Json;
using AdyenBridge.Contracts;

namespace AdyenBridge.Application;

public sealed class WebhookParser(AdyenHmacVerifier hmacVerifier)
{
    public IReadOnlyList<RawWebhookMessage> ParseAndValidate(string json, AdyenOptions options, DateTimeOffset receivedAtUtc)
    {
        var payload = JsonSerializer.Deserialize<AdyenWebhookPayload>(json, ContractJson.SerializerOptions)
            ?? throw new JsonException("The webhook payload is empty.");

        var expectedLive = string.Equals(options.Environment, "live", StringComparison.OrdinalIgnoreCase);
        var actualLive = ParseLive(payload.Live);
        if (actualLive != expectedLive)
        {
            throw new SecurityException("The webhook environment does not match this endpoint.");
        }

        if (payload.NotificationItems.Count == 0)
        {
            throw new InvalidDataException("The webhook contains no notification items.");
        }

        var result = new List<RawWebhookMessage>(payload.NotificationItems.Count);
        var payloadHash = Hashing.Sha256(json);
        for (var itemIndex = 0; itemIndex < payload.NotificationItems.Count; itemIndex++)
        {
            var container = payload.NotificationItems[itemIndex];
            var item = container.Item;
            if (!string.Equals(item.MerchantAccountCode, options.MerchantAccount, StringComparison.Ordinal))
            {
                throw new SecurityException("The merchant account is not accepted by this endpoint.");
            }

            if (!hmacVerifier.Verify(item, options.HmacKeys))
            {
                throw new SecurityException("The webhook HMAC signature is invalid.");
            }

            var notificationJson = JsonSerializer.Serialize(item, ContractJson.SerializerOptions);
            var logicalKey = BuildLogicalEventKey(item);
            result.Add(new RawWebhookMessage
            {
                TransportId = Hashing.Sha256(string.Join('|', payloadHash, itemIndex)),
                LogicalEventKey = logicalKey,
                ReceivedAtUtc = receivedAtUtc,
                Live = actualLive,
                RawPayloadJson = json,
                NotificationJson = notificationJson,
                PayloadHash = payloadHash
            });
        }

        return result;
    }

    public static string BuildLogicalEventKey(AdyenNotificationItem item) =>
        string.Join('|', item.MerchantAccountCode, item.EventCode, item.PspReference, item.Success).ToLowerInvariant();

    public static string GetShopperReference(AdyenNotificationItem item) =>
        item.AdditionalData.TryGetValue("shopperReference", out var value) ? value : string.Empty;

    private static bool ParseLive(string value) => value switch
    {
        "true" => true,
        "false" => false,
        _ => throw new JsonException("The webhook live property must be 'true' or 'false'.")
    };
}
