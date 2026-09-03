using System.Security.Cryptography;
using System.Text;
using AdyenBridge.Contracts;

namespace AdyenBridge.Application;

public sealed class AdyenHmacVerifier
{
    public bool Verify(AdyenNotificationItem item, IEnumerable<string> hexadecimalKeys)
    {
        if (!item.AdditionalData.TryGetValue("hmacSignature", out var suppliedSignature) ||
            string.IsNullOrWhiteSpace(suppliedSignature))
        {
            return false;
        }

        byte[] suppliedBytes;
        try
        {
            suppliedBytes = Convert.FromBase64String(suppliedSignature);
        }
        catch (FormatException)
        {
            return false;
        }

        foreach (var key in hexadecimalKeys.Where(static key => !string.IsNullOrWhiteSpace(key)))
        {
            byte[] keyBytes;
            try
            {
                keyBytes = Convert.FromHexString(key.Trim());
            }
            catch (FormatException)
            {
                continue;
            }

            var computed = ComputeSignatureBytes(item, keyBytes);
            if (CryptographicOperations.FixedTimeEquals(computed, suppliedBytes))
            {
                return true;
            }
        }

        return false;
    }

    public string ComputeSignature(AdyenNotificationItem item, string hexadecimalKey) =>
        Convert.ToBase64String(ComputeSignatureBytes(item, Convert.FromHexString(hexadecimalKey)));

    private static byte[] ComputeSignatureBytes(AdyenNotificationItem item, byte[] key)
    {
        var signingValue = string.Join(':',
            Escape(item.PspReference),
            Escape(item.OriginalReference),
            Escape(item.MerchantAccountCode),
            Escape(item.MerchantReference),
            item.Amount.Value.ToString(System.Globalization.CultureInfo.InvariantCulture),
            Escape(item.Amount.Currency),
            Escape(item.EventCode),
            Escape(item.Success));

        return HMACSHA256.HashData(key, Encoding.UTF8.GetBytes(signingValue));
    }

    private static string Escape(string value) => value.Replace("\\", "\\\\", StringComparison.Ordinal).Replace(":", "\\:", StringComparison.Ordinal);
}

