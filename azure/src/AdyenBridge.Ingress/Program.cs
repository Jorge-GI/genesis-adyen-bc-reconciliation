using AdyenBridge.Application;
using Azure.Identity;
using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var builder = FunctionsApplication.CreateBuilder(args);
builder.ConfigureFunctionsWebApplication();

builder.Services.AddOptions<AdyenOptions>()
    .BindConfiguration(AdyenOptions.SectionName)
    .Validate(options => !string.IsNullOrWhiteSpace(options.MerchantAccount), "Adyen merchant account is required.")
    .Validate(options => options.HmacKeys.Length > 0, "At least one Adyen HMAC key is required.")
    .ValidateOnStart();
builder.Services.AddOptions<IngressOptions>().BindConfiguration(IngressOptions.SectionName);
builder.Services.AddSingleton<AdyenHmacVerifier>();
builder.Services.AddSingleton<WebhookParser>();
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
builder.Services.AddSingleton(serviceProvider =>
{
    var configuration = serviceProvider.GetRequiredService<IConfiguration>();
    var queueName = configuration["WebhookQueueName"]
        ?? throw new InvalidOperationException("WebhookQueueName is required.");
    return serviceProvider.GetRequiredService<ServiceBusClient>().CreateSender(queueName);
});

builder.Build().Run();
