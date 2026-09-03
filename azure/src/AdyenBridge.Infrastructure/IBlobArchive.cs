namespace AdyenBridge.Infrastructure;

public interface IBlobArchive
{
    Task<string> ArchiveAsync(string containerName, string blobName, BinaryData content, string contentType, string hash, CancellationToken cancellationToken);
}

