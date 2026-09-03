using System.Security;
using System.Text.Json;
using AdyenBridge.Application;
using AdyenBridge.Contracts;

namespace AdyenBridge.Application.Tests;

public sealed class WebhookParserTests
{
    private const string Key = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff";

    [Fact]
    public void ParseAndValidateCreatesStableTransportAndLogicalKeys()
    {
        var parser = new WebhookParser(new AdyenHmacVerifier());
        var json = CreateSignedPayload(CreateItem(), live: "false");

        var first = Assert.Single(parser.ParseAndValidate(json, CreateOptions(), DateTimeOffset.UtcNow));
        var second = Assert.Single(parser.ParseAndValidate(json, CreateOptions(), DateTimeOffset.UtcNow.AddMinutes(1)));

        Assert.Equal(first.TransportId, second.TransportId);
        Assert.Equal(first.LogicalEventKey, second.LogicalEventKey);
        Assert.Equal(json, first.RawPayloadJson);
        Assert.Equal(Hashing.Sha256(json), first.PayloadHash);
    }

    [Fact]
    public void ChangedEventTimeKeepsLogicalKeyButCreatesAuditableTransport()
    {
        var parser = new WebhookParser(new AdyenHmacVerifier());
        var firstItem = CreateItem();
        var secondItem = firstItem with { EventDate = firstItem.EventDate.AddMinutes(1) };

        var first = Assert.Single(parser.ParseAndValidate(
            CreateSignedPayload(firstItem, "false"), CreateOptions(), DateTimeOffset.UtcNow));
        var second = Assert.Single(parser.ParseAndValidate(
            CreateSignedPayload(secondItem, "false"), CreateOptions(), DateTimeOffset.UtcNow));

        Assert.Equal(first.LogicalEventKey, second.LogicalEventKey);
        Assert.NotEqual(first.TransportId, second.TransportId);
    }

    [Fact]
    public void ParseAndValidateRejectsWrongMerchant()
    {
        var parser = new WebhookParser(new AdyenHmacVerifier());
        var item = CreateItem() with { MerchantAccountCode = "OtherMerchant" };

        Assert.Throws<SecurityException>(() => parser.ParseAndValidate(
            CreateSignedPayload(item, "false"), CreateOptions(), DateTimeOffset.UtcNow));
    }

    [Fact]
    public void ParseAndValidateRejectsWrongEnvironment()
    {
        var parser = new WebhookParser(new AdyenHmacVerifier());

        Assert.Throws<SecurityException>(() => parser.ParseAndValidate(
            CreateSignedPayload(CreateItem(), "true"), CreateOptions(), DateTimeOffset.UtcNow));
    }

    private static AdyenNotificationItem CreateItem() => new()
    {
        AdditionalData = new Dictionary<string, string> { ["shopperReference"] = "C10000" },
        Amount = new AdyenAmount { Currency = "EUR", Value = 1000 },
        EventCode = "AUTHORISATION",
        EventDate = DateTimeOffset.Parse("2026-09-03T10:00:00Z", System.Globalization.CultureInfo.InvariantCulture),
        MerchantAccountCode = "GenesisMerchant",
        MerchantReference = "ORDER-1",
        PaymentMethod = "visa",
        PspReference = "8831234567890123",
        Success = "true"
    };

    private static AdyenOptions CreateOptions() => new()
    {
        MerchantAccount = "GenesisMerchant",
        Environment = "test",
        HmacKeys = [Key]
    };

    private static string CreateSignedPayload(AdyenNotificationItem unsigned, string live)
    {
        var verifier = new AdyenHmacVerifier();
        var signature = verifier.ComputeSignature(unsigned, Key);
        var signed = unsigned with
        {
            AdditionalData = new Dictionary<string, string>(unsigned.AdditionalData)
            {
                ["hmacSignature"] = signature
            }
        };
        var payload = new AdyenWebhookPayload
        {
            Live = live,
            NotificationItems = [new AdyenNotificationContainer { Item = signed }]
        };
        return JsonSerializer.Serialize(payload, ContractJson.SerializerOptions);
    }
}
