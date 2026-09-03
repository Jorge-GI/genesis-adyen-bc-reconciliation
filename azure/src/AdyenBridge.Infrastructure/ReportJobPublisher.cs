using System.Text.Json;
using AdyenBridge.Contracts;
using Azure.Messaging.ServiceBus;

namespace AdyenBridge.Infrastructure;

public sealed class ReportJobPublisher(ServiceBusSender sender) : IReportJobPublisher
{
    public Task PublishAsync(ReportJobMessage reportJob, CancellationToken cancellationToken)
    {
        var message = new ServiceBusMessage(JsonSerializer.Serialize(reportJob, ContractJson.SerializerOptions))
        {
            MessageId = reportJob.TransportId,
            CorrelationId = reportJob.ExternalReportId,
            ContentType = "application/json",
            Subject = "REPORT_AVAILABLE"
        };
        return sender.SendMessageAsync(message, cancellationToken);
    }
}
