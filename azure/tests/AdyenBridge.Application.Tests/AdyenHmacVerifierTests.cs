using AdyenBridge.Application;
using AdyenBridge.Contracts;

namespace AdyenBridge.Application.Tests;

public sealed class AdyenHmacVerifierTests
{
    private const string Key = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff";

    [Fact]
    public void VerifyAcceptsSignatureFromCurrentKey()
    {
        var verifier = new AdyenHmacVerifier();
        var unsigned = CreateItem(new Dictionary<string, string>());
        var signature = verifier.ComputeSignature(unsigned, Key);
        var signed = unsigned with
        {
            AdditionalData = new Dictionary<string, string> { ["hmacSignature"] = signature }
        };

        Assert.True(verifier.Verify(signed, [Key]));
    }

    [Fact]
    public void VerifyRejectsChangedAmount()
    {
        var verifier = new AdyenHmacVerifier();
        var unsigned = CreateItem(new Dictionary<string, string>());
        var signature = verifier.ComputeSignature(unsigned, Key);
        var changed = unsigned with
        {
            Amount = unsigned.Amount with { Value = unsigned.Amount.Value + 1 },
            AdditionalData = new Dictionary<string, string> { ["hmacSignature"] = signature }
        };

        Assert.False(verifier.Verify(changed, [Key]));
    }

    [Fact]
    public void VerifyAcceptsPreviousKeyDuringRotation()
    {
        const string CurrentKey = "111122223333444455556666777788889999aaaabbbbccccddddeeeeffff0000";
        var verifier = new AdyenHmacVerifier();
        var unsigned = CreateItem(new Dictionary<string, string>());
        var signed = unsigned with
        {
            AdditionalData = new Dictionary<string, string>
            {
                ["hmacSignature"] = verifier.ComputeSignature(unsigned, Key)
            }
        };

        Assert.True(verifier.Verify(signed, [CurrentKey, Key]));
    }

    [Fact]
    public void VerifyRejectsMalformedBase64Signature()
    {
        var verifier = new AdyenHmacVerifier();
        var signed = CreateItem(new Dictionary<string, string> { ["hmacSignature"] = "not-base64" });

        Assert.False(verifier.Verify(signed, [Key]));
    }

    private static AdyenNotificationItem CreateItem(IReadOnlyDictionary<string, string> data) => new()
    {
        AdditionalData = data,
        Amount = new AdyenAmount { Currency = "EUR", Value = 12345 },
        EventCode = "AUTHORISATION",
        EventDate = DateTimeOffset.Parse("2026-09-03T10:00:00Z", System.Globalization.CultureInfo.InvariantCulture),
        MerchantAccountCode = "GenesisMerchant",
        MerchantReference = "ORDER-1",
        PspReference = "8831234567890123",
        Success = "true"
    };
}
