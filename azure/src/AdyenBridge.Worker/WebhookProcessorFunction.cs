using System.Text.Json;
using AdyenBridge.Application;
using AdyenBridge.Contracts;
using AdyenBridge.Infrastructure;
using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace AdyenBridge.Worker;

public sealed class WebhookProcessorFunction(
    WebhookNormalizer normalizer,
    IBlobArchive archive,
    IBusinessCentralClient businessCentral,
    IReportJobPublisher reportJobs,
    ILogger<WebhookProcessorFunction> logger)
{
    [Function("ProcessAdyenWebhook")]
    public async Task RunAsync(
        [ServiceBusTrigger("%WebhookQueueName%", Connection = "ServiceBus", AutoCompleteMessages = false)] ServiceBusReceivedMessage message,
        ServiceBusMessageActions messageActions,
        CancellationToken cancellationToken)
    {
        RawWebhookMessage raw;
        try
        {
            raw = JsonSerializer.Deserialize<RawWebhookMessage>(message.Body, ContractJson.SerializerOptions)
                ?? throw new JsonException("The queue message is empty.");
        }
        catch (JsonException exception)
        {
            await messageActions.DeadLetterMessageAsync(message,
                deadLetterReason: "InvalidEnvelope", deadLetterErrorDescription: exception.Message,
                cancellationToken: cancellationToken);
            return;
        }

        try
        {
            var item = normalizer.Deserialize(raw);
            var blobName = $"{raw.ReceivedAtUtc:yyyy/MM/dd}/{raw.PayloadHash}.json";
            var archiveReference = await archive.ArchiveAsync(
                "adyen-webhooks-raw", blobName, BinaryData.FromString(raw.RawPayloadJson),
                "application/json", raw.PayloadHash, cancellationToken);

            if (string.Equals(item.EventCode, "REPORT_AVAILABLE", StringComparison.OrdinalIgnoreCase))
            {
                if (!Uri.TryCreate(item.Reason, UriKind.Absolute, out var reportUri))
                {
                    await messageActions.DeadLetterMessageAsync(message,
                        deadLetterReason: "InvalidReportUri",
                        deadLetterErrorDescription: "REPORT_AVAILABLE has no valid download URI.",
                        cancellationToken: cancellationToken);
                    return;
                }

                await reportJobs.PublishAsync(new ReportJobMessage
                {
                    TransportId = raw.TransportId,
                    ExternalReportId = item.PspReference,
                    DownloadUri = reportUri,
                    OccurredAtUtc = item.EventDate,
                    MerchantAccount = item.MerchantAccountCode,
                    Live = raw.Live,
                    SourceArchiveReference = archiveReference
                }, cancellationToken);
            }
            else
            {
                var inbound = normalizer.Normalize(raw, item, archiveReference);
                await businessCentral.SubmitInboundMessageAsync(inbound, cancellationToken);
            }

            await messageActions.CompleteMessageAsync(message, cancellationToken);
            logger.LogInformation("Processed Adyen webhook transport {TransportId}.", raw.TransportId);
        }
        catch (JsonException exception)
        {
            await messageActions.DeadLetterMessageAsync(message,
                deadLetterReason: "InvalidNotification", deadLetterErrorDescription: exception.Message,
                cancellationToken: cancellationToken);
        }
    }
}
