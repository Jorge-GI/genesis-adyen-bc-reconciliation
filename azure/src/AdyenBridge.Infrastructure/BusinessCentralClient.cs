using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Azure.Core;
using Azure.Identity;
using AdyenBridge.Contracts;
using Microsoft.Extensions.Options;

namespace AdyenBridge.Infrastructure;

public sealed class BusinessCentralClient : IBusinessCentralClient
{
    private static readonly string[] Scopes = ["https://api.businesscentral.dynamics.com/.default"];
    private readonly HttpClient _httpClient;
    private readonly BusinessCentralOptions _options;
    private readonly ClientSecretCredential _credential;
    private readonly Uri _companyApiUri;

    public BusinessCentralClient(HttpClient httpClient, IOptions<BusinessCentralOptions> options)
    {
        _httpClient = httpClient;
        _options = options.Value;
        _credential = new ClientSecretCredential(_options.TenantId, _options.ClientId, _options.ClientSecret);
        _companyApiUri = new Uri(
            $"{_options.ApiBaseUri.TrimEnd('/')}/v2.0/{Uri.EscapeDataString(_options.TenantId)}/" +
            $"{Uri.EscapeDataString(_options.EnvironmentName)}/api/genesisimport/adyen/v1.0/" +
            $"companies({_options.CompanyId})/");
    }

    public Task SubmitInboundMessageAsync(InboundMessageV1 message, CancellationToken cancellationToken) =>
        SendAsync(HttpMethod.Post, "adyenInboundMessages", message, allowConflict: true, cancellationToken);

    public Task CreateReportRunAsync(ReportRunV1 reportRun, CancellationToken cancellationToken) =>
        SendAsync(HttpMethod.Post, "adyenReportRuns", reportRun, allowConflict: true, cancellationToken);

    public Task UpdateReportRunAsync(string externalReportId, ReportRunUpdateV1 update, CancellationToken cancellationToken)
    {
        var escapedKey = Uri.EscapeDataString(externalReportId.Replace("'", "''", StringComparison.Ordinal));
        return SendAsync(HttpMethod.Patch, $"adyenReportRuns('{escapedKey}')", update, allowConflict: false, cancellationToken);
    }

    private async Task SendAsync<T>(HttpMethod method, string relativeUri, T payload, bool allowConflict, CancellationToken cancellationToken)
    {
        var token = await _credential.GetTokenAsync(new TokenRequestContext(Scopes), cancellationToken);
        using var request = new HttpRequestMessage(method, new Uri(_companyApiUri, relativeUri));
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        if (method == HttpMethod.Patch)
        {
            request.Headers.TryAddWithoutValidation("If-Match", "*");
        }
        request.Content = JsonContent.Create(payload, options: ContractJson.SerializerOptions);

        using var response = await _httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        if (allowConflict && response.StatusCode == HttpStatusCode.Conflict)
        {
            return;
        }
        if (!response.IsSuccessStatusCode)
        {
            throw new HttpRequestException(
                $"Business Central API call to '{relativeUri}' failed with {(int)response.StatusCode} {response.ReasonPhrase}.",
                inner: null,
                response.StatusCode);
        }
    }
}

