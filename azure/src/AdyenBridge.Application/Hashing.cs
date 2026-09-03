using System.Security.Cryptography;
using System.Text;

namespace AdyenBridge.Application;

public static class Hashing
{
    public static string Sha256(string value) => Sha256(Encoding.UTF8.GetBytes(value));

    public static string Sha256(ReadOnlySpan<byte> value) => Convert.ToHexString(SHA256.HashData(value)).ToLowerInvariant();
}

