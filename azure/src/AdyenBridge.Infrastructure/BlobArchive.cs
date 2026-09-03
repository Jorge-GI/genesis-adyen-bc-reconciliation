using Azure;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;

namespace AdyenBridge.Infrastructure;

public sealed class BlobArchive(BlobServiceClient blobServiceClient) : IBlobArchive
{
    public async Task<string> ArchiveAsync(string containerName, string blobName, BinaryData content, string contentType, string hash, CancellationToken cancellationToken)
    {
        var container = blobServiceClient.GetBlobContainerClient(containerName);
        await container.CreateIfNotExistsAsync(PublicAccessType.None, cancellationToken: cancellationToken);
        var blob = container.GetBlobClient(blobName);
        try
        {
            await blob.UploadAsync(content, new BlobUploadOptions
            {
                HttpHeaders = new BlobHttpHeaders { ContentType = contentType },
                Metadata = new Dictionary<string, string> { ["sha256"] = hash }
            }, cancellationToken);
        }
        catch (RequestFailedException exception) when (exception.Status == 409)
        {
            // Deterministic names make an already archived payload an idempotent success.
        }

        return blob.Uri.ToString();
    }
}

