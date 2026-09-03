using System.Net;
using System.Net.Http.Headers;
using System.Text;
using AdyenBridge.Application;
using Microsoft.Extensions.Options;

namespace AdyenBridge.Infrastructure;

public sealed class ReportDownloader(HttpClient httpClient, IOptions<ReportOptions> options) : IReportDownloader
{
    private readonly ReportOptions _options = options.Value;

    public async Task<byte[]> DownloadAsync(Uri uri, CancellationToken cancellationToken)
    {
        var current = uri;
        for (var redirects = 0; redirects <= 5; redirects++)
        {
            ValidateUri(current);
            using var request = new HttpRequestMessage(HttpMethod.Get, current);
            var credentials = Convert.ToBase64String(Encoding.UTF8.GetBytes($"{_options.Username}:{_options.Password}"));
            request.Headers.Authorization = new AuthenticationHeaderValue("Basic", credentials);
            using var response = await httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);

            if (IsRedirect(response.StatusCode))
            {
                if (response.Headers.Location is null)
                {
                    throw new InvalidDataException("The report download redirect has no Location header.");
                }
                current = response.Headers.Location.IsAbsoluteUri
                    ? response.Headers.Location
                    : new Uri(current, response.Headers.Location);
                continue;
            }

            response.EnsureSuccessStatusCode();
            if (response.Content.Headers.ContentLength > _options.MaxFileBytes)
            {
                throw new InvalidDataException("The report exceeds the configured maximum size.");
            }

            await using var input = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var output = new MemoryStream();
            var buffer = new byte[81920];
            int read;
            while ((read = await input.ReadAsync(buffer, cancellationToken)) > 0)
            {
                if (output.Length + read > _options.MaxFileBytes)
                {
                    throw new InvalidDataException("The report exceeds the configured maximum size.");
                }
                await output.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
            }
            return output.ToArray();
        }

        throw new InvalidDataException("The report download exceeded five redirects.");
    }

    private void ValidateUri(Uri uri)
    {
        if (uri.Scheme != Uri.UriSchemeHttps)
        {
            throw new InvalidDataException("Report downloads must use HTTPS.");
        }

        var allowed = _options.AllowedHosts.Any(host =>
            uri.Host.Equals(host, StringComparison.OrdinalIgnoreCase) ||
            uri.Host.EndsWith($".{host}", StringComparison.OrdinalIgnoreCase));
        if (!allowed)
        {
            throw new InvalidDataException($"The report host '{uri.Host}' is not allowed.");
        }
    }

    private static bool IsRedirect(HttpStatusCode statusCode) => statusCode is
        HttpStatusCode.Moved or HttpStatusCode.Redirect or HttpStatusCode.RedirectMethod or
        HttpStatusCode.TemporaryRedirect or HttpStatusCode.PermanentRedirect;
}

