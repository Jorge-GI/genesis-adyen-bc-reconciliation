namespace AdyenBridge.Infrastructure;

public interface IReportDownloader
{
    Task<byte[]> DownloadAsync(Uri uri, CancellationToken cancellationToken);
}

