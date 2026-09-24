using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.EntityFrameworkCore;
using MiniCrm.Infrastructure.Persistence.Entities;
using MiniCrm.Core.Services;
using MiniCrm.Infrastructure.Persistence.Configurations;
using MiniCrm.Infrastructure.Persistence;

namespace MiniCrm.Infrastructure.Services;

public sealed class AuditService(IDbContextFactory<AppDbContext> dbFactory) : IAuditService
{
    private readonly IDbContextFactory<AppDbContext> _dbFactory = dbFactory;

    public async Task LogAsync(
        string action,
        string? entityName = null,
        string? entityId = null,
        object? details = null,
        Guid? userId = null,
        string? ipAddress = null,
        CancellationToken cancellationToken = default)
    {
        string? jsonDetails = null;

        if (details != null)
        {
            jsonDetails = SerializeAndSanitize(details);
        }

        var log = new AuditLog
        {
            OccurredAtUtc = DateTime.UtcNow,
            Action = action,
            EntityName = entityName,
            EntityId = entityId,
            Details = jsonDetails,
            UserId = userId,
            IpAddress = ipAddress
        };

        await using AppDbContext db = await _dbFactory.CreateDbContextAsync(cancellationToken);
        db.AuditLogs.Add(log);
        await db.SaveChangesAsync(cancellationToken);
    }

    public static string SerializeAndSanitize(object details)
    {
        string jsonString = JsonSerializer.Serialize(details);
        var node = JsonNode.Parse(jsonString);

        if (node is JsonObject obj)
        {
            SanitizeObject(obj);
            return obj.ToJsonString();
        }

        return jsonString;
    }

    private static void SanitizeObject(JsonObject obj)
    {
        string[] sensitiveKeys = ["password", "token", "hash", "secret", "passwordhash", "securitystamp"];
        var keysToRemove = new List<string>();

        foreach (KeyValuePair<string, JsonNode?> kvp in obj)
        {
            string keyLower = kvp.Key.ToLowerInvariant();
            if (sensitiveKeys.Any(s => keyLower.Contains(s)))
            {
                keysToRemove.Add(kvp.Key);
            }
            else if (kvp.Value is JsonObject childObj)
            {
                SanitizeObject(childObj);
            }
        }

        foreach (string key in keysToRemove)
        {
            obj.Remove(key);
        }
    }
}
