using AdyenBridge.Contracts;

namespace AdyenBridge.Infrastructure;

public interface IBusinessCentralClient
{
    Task SubmitInboundMessageAsync(InboundMessageV1 message, CancellationToken cancellationToken);
    Task CreateReportRunAsync(ReportRunV1 reportRun, CancellationToken cancellationToken);
    Task UpdateReportRunAsync(string externalReportId, ReportRunUpdateV1 update, CancellationToken cancellationToken);
}

