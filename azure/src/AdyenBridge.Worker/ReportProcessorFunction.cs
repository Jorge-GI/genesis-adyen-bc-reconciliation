using System.Text.Json;
using AdyenBridge.Application;
using AdyenBridge.Contracts;
using AdyenBridge.Infrastructure;
using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace AdyenBridge.Worker;

public sealed class ReportProcessorFunction(
    IReportDownloader downloader,
    IBlobArchive archive,
    PaymentAccountingReportParser parser,
    IBusinessCentralClient businessCentral,
    IOptions<ReportOptions> reportOptions,
    ILogger<ReportProcessorFunction> logger)
{
    [Function("ProcessAdyenReport")]
    public async Task RunAsync(
        [ServiceBusTrigger("%ReportQueueName%", Connection = "ServiceBus", AutoCompleteMessages = false)] ServiceBusReceivedMessage message,
        ServiceBusMessageActions messageActions,
        CancellationToken cancellationToken)
    {
        ReportJobMessage job;
        try
        {
            job = JsonSerializer.Deserialize<ReportJobMessage>(message.Body, ContractJson.SerializerOptions)
                ?? throw new JsonException("The report job is empty.");
        }
        catch (JsonException exception)
        {
            await messageActions.DeadLetterMessageAsync(message,
                deadLetterReason: "InvalidReportJob", deadLetterErrorDescription: exception.Message,
                cancellationToken: cancellationToken);
            return;
        }

        var runCreated = false;
        try
        {
            var content = await downloader.DownloadAsync(job.DownloadUri, cancellationToken);
            var fileHash = Hashing.Sha256(content);
            var safeName = string.Concat(job.ExternalReportId.Select(character =>
                char.IsLetterOrDigit(character) || character is '-' or '_' or '.' ? character : '_'));
            var blobName = $"{job.OccurredAtUtc:yyyy/MM/dd}/{fileHash}-{safeName}";
            var archiveReference = await archive.ArchiveAsync(
                "adyen-reports", blobName, BinaryData.FromBytes(content), "text/csv", fileHash, cancellationToken);
            var reportDate = ReportDateResolver.FromExternalReportId(job.ExternalReportId);

            await businessCentral.CreateReportRunAsync(new ReportRunV1
            {
                ExternalReportId = job.ExternalReportId,
                FileHash = fileHash,
                ReportDate = reportDate,
                State = ReportRunState.Loading,
                ArchiveReference = archiveReference
            }, cancellationToken);
            runCreated = true;

            var parsed = parser.Parse(content, job.ExternalReportId, fileHash, archiveReference,
                reportOptions.Value, DateTimeOffset.UtcNow);
            var loaded = 0;
            foreach (var row in parsed.RelevantRows)
            {
                await businessCentral.SubmitInboundMessageAsync(row, cancellationToken);
                loaded++;
            }

            await businessCentral.UpdateReportRunAsync(job.ExternalReportId, new ReportRunUpdateV1
            {
                State = ReportRunState.Ready,
                TotalRowCount = parsed.TotalRows,
                RelevantRowCount = parsed.RelevantRows.Count,
                LoadedRowCount = loaded
            }, cancellationToken);

            await messageActions.CompleteMessageAsync(message, cancellationToken);
            logger.LogInformation("Loaded report {ReportId} with {RelevantRows} relevant row(s).",
                job.ExternalReportId, parsed.RelevantRows.Count);
        }
        catch (InvalidDataException exception)
        {
            if (runCreated)
            {
                await TryMarkErrorAsync(job.ExternalReportId, exception.Message, cancellationToken);
            }
            await messageActions.DeadLetterMessageAsync(message,
                deadLetterReason: "InvalidReport", deadLetterErrorDescription: exception.Message,
                cancellationToken: cancellationToken);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            if (runCreated)
            {
                await TryMarkErrorAsync(job.ExternalReportId, exception.Message, cancellationToken);
            }
            throw;
        }
    }

    private async Task TryMarkErrorAsync(string reportId, string errorMessage, CancellationToken cancellationToken)
    {
        try
        {
            await businessCentral.UpdateReportRunAsync(reportId, new ReportRunUpdateV1
            {
                State = ReportRunState.Error,
                TotalRowCount = 0,
                RelevantRowCount = 0,
                LoadedRowCount = 0,
                ErrorMessage = errorMessage.Length <= 2048 ? errorMessage : errorMessage[..2048]
            }, cancellationToken);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            logger.LogError(exception, "Could not mark report {ReportId} as failed.", reportId);
        }
    }
}
