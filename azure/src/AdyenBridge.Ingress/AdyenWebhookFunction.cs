using System.Security;
using System.Text.Json;
using AdyenBridge.Application;
using AdyenBridge.Contracts;
using Azure.Messaging.ServiceBus;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace AdyenBridge.Ingress;

public sealed class AdyenWebhookFunction(
    WebhookParser parser,
    ServiceBusSender sender,
    IOptions<AdyenOptions> adyenOptions,
    IOptions<IngressOptions> ingressOptions,
    ILogger<AdyenWebhookFunction> logger)
{
    [Function("AdyenStandardWebhook")]
    public async Task<IActionResult> RunAsync(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "adyen/webhooks/standard")] HttpRequest request,
        CancellationToken cancellationToken)
    {
        if (ingressOptions.Value.RequireEasyAuthPrincipal &&
            !request.Headers.ContainsKey("X-MS-CLIENT-PRINCIPAL") &&
            !request.Headers.ContainsKey("X-MS-CLIENT-PRINCIPAL-ID"))
        {
            return new UnauthorizedResult();
        }

        if (request.ContentType is null || !request.ContentType.StartsWith("application/json", StringComparison.OrdinalIgnoreCase))
        {
            return new UnsupportedMediaTypeResult();
        }

        try
        {
            var body = await ReadBodyAsync(request, adyenOptions.Value.MaxBodyBytes, cancellationToken);
            var queuedItems = parser.ParseAndValidate(body, adyenOptions.Value, DateTimeOffset.UtcNow);
            var messages = queuedItems.Select(CreateServiceBusMessage).ToArray();
            await sender.SendMessagesAsync(messages, cancellationToken);
            logger.LogInformation("Accepted {Count} Adyen notification item(s).", messages.Length);
            return new AcceptedResult();
        }
        catch (SecurityException exception)
        {
            logger.LogWarning("Rejected an Adyen webhook: {Reason}", exception.Message);
            return new UnauthorizedObjectResult(new { error = "Webhook authentication failed." });
        }
        catch (JsonException exception)
        {
            logger.LogWarning("Rejected malformed Adyen JSON: {Reason}", exception.Message);
            return new BadRequestObjectResult(new { error = "Malformed webhook payload." });
        }
        catch (InvalidDataException exception)
        {
            logger.LogWarning("Rejected invalid Adyen data: {Reason}", exception.Message);
            return new BadRequestObjectResult(new { error = exception.Message });
        }
        catch (ServiceBusException exception)
        {
            logger.LogError(exception, "Could not durably enqueue the Adyen webhook.");
            return new StatusCodeResult(StatusCodes.Status503ServiceUnavailable);
        }
    }

    private static ServiceBusMessage CreateServiceBusMessage(RawWebhookMessage raw) => new(
        JsonSerializer.Serialize(raw, ContractJson.SerializerOptions))
    {
        MessageId = raw.TransportId,
        CorrelationId = raw.LogicalEventKey.Length <= 128
            ? raw.LogicalEventKey
            : Hashing.Sha256(raw.LogicalEventKey),
        ContentType = "application/json",
        Subject = "ADYEN_STANDARD_WEBHOOK"
    };

    private static async Task<string> ReadBodyAsync(HttpRequest request, int maximumBytes, CancellationToken cancellationToken)
    {
        if (request.ContentLength > maximumBytes)
        {
            throw new InvalidDataException("The webhook exceeds the configured maximum size.");
        }

        using var buffer = new MemoryStream();
        var bytes = new byte[81920];
        int read;
        while ((read = await request.Body.ReadAsync(bytes, cancellationToken)) > 0)
        {
            if (buffer.Length + read > maximumBytes)
            {
                throw new InvalidDataException("The webhook exceeds the configured maximum size.");
            }
            await buffer.WriteAsync(bytes.AsMemory(0, read), cancellationToken);
        }
        return System.Text.Encoding.UTF8.GetString(buffer.GetBuffer(), 0, checked((int)buffer.Length));
    }
}
