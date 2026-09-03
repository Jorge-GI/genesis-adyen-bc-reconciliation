using AdyenBridge.Contracts;

namespace AdyenBridge.Infrastructure;

public interface IReportJobPublisher
{
    Task PublishAsync(ReportJobMessage reportJob, CancellationToken cancellationToken);
}

