namespace MiniCrm.Core.Services;

public interface IAuditService
{
    Task LogAsync(string action, string? entityName = null, string? entityId = null, object? details = null, Guid? userId = null, string? ipAddress = null, CancellationToken cancellationToken = default);
}
