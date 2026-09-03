namespace AdyenBridge.Infrastructure;

public sealed class BusinessCentralOptions
{
    public const string SectionName = "BusinessCentral";
    public string TenantId { get; set; } = string.Empty;
    public string EnvironmentName { get; set; } = string.Empty;
    public string CompanyId { get; set; } = string.Empty;
    public string ClientId { get; set; } = string.Empty;
    public string ClientSecret { get; set; } = string.Empty;
    public string ApiBaseUri { get; set; } = "https://api.businesscentral.dynamics.com";
}

