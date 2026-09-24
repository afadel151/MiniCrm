using System;
using System.Collections.Generic;
namespace MiniCrm.Infrastructure.Persistence.Entities;

public partial class AuditLog
{
    public long Id { get; set; }

    public DateTime OccurredAtUtc { get; set; }

    public Guid? UserId { get; set; }

    public string Action { get; set; } = null!;

    public string? EntityName { get; set; }

    public string? EntityId { get; set; }

    public string? Details { get; set; }

    public string? IpAddress { get; set; }
}
