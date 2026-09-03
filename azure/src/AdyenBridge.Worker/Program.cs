using AdyenBridge.Application;
using AdyenBridge.Infrastructure;
using Azure.Identity;
using Azure.Messaging.ServiceBus;
using Azure.Storage.Blobs;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var builder = FunctionsApplication.CreateBuilder(args);

builder.Services.AddOptions<ReportOptions>()
    .BindConfiguration(ReportOptions.SectionName)
    .Validate(options => options.AllowedHosts.Length > 0, "At least one report host is required.")
    .ValidateOnStart();
builder.Services.AddOptions<BusinessCentralOptions>()
    .BindConfiguration(BusinessCentralOptions.SectionName)
    .Validate(options => Guid.TryParse(options.TenantId, out _), "A valid Business Central tenant ID is required.")
    .Validate(options => Guid.TryParse(options.CompanyId, out _), "A valid Business Central company ID is required.")
    .Validate(options => !string.IsNullOrWhiteSpace(options.ClientId), "Business Central client ID is required.")
    .Validate(options => !string.IsNullOrWhiteSpace(options.ClientSecret), "Business Central client secret is required.")
    .ValidateOnStart();

builder.Services.AddSingleton<WebhookNormalizer>();
builder.Services.AddSingleton<PaymentAccountingReportParser>();
builder.Services.AddHttpClient<IBusinessCentralClient, BusinessCentralClient>();
builder.Services.AddHttpClient<IReportDownloader, ReportDownloader>()
    .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });

builder.Services.AddSingleton(serviceProvider =>
{
    var configuration = serviceProvider.GetRequiredService<IConfiguration>();
    var connectionString = configuration["ServiceBusConnectionString"];
    return !string.IsNullOrWhiteSpace(connectionString)
        ? new ServiceBusClient(connectionString)
        : new ServiceBusClient(
            configuration["ServiceBus:fullyQualifiedNamespace"]
                ?? throw new InvalidOperationException("ServiceBus:fullyQualifiedNamespace is required."),
            new DefaultAzureCredential());
});
builder.Services.AddSingleton<IReportJobPublisher>(serviceProvider =>
{
    var configuration = serviceProvider.GetRequiredService<IConfiguration>();
    var queueName = configuration["ReportQueueName"]
        ?? throw new InvalidOperationException("ReportQueueName is required.");
    var sender = serviceProvider.GetRequiredService<ServiceBusClient>().CreateSender(queueName);
    return new ReportJobPublisher(sender);
});
builder.Services.AddSingleton(serviceProvider =>
{
    var configuration = serviceProvider.GetRequiredService<IConfiguration>();
    var connectionString = configuration["AzureWebJobsStorage"];
    var serviceUri = configuration["BlobServiceUri"];
    return !string.IsNullOrWhiteSpace(serviceUri)
        ? new BlobServiceClient(new Uri(serviceUri), new DefaultAzureCredential())
        : new BlobServiceClient(connectionString
            ?? throw new InvalidOperationException("BlobServiceUri or AzureWebJobsStorage is required."));
});
builder.Services.AddSingleton<IBlobArchive, BlobArchive>();

builder.Build().Run();
