using System;
using System.Collections.Generic;
using MiniCrm.Infrastructure.Identity;
namespace MiniCrm.Infrastructure.Persistence.Entities;

public partial class RefreshToken
{
    public int Id { get; set; }

    public Guid UserId { get; set; }

    public string TokenHash { get; set; } = null!;

    public DateTime CreatedAtUtc { get; set; }

    public DateTime ExpiresAtUtc { get; set; }

    public string? CreatedByIp { get; set; }

    public DateTime? RevokedAtUtc { get; set; }

    public string? ReplacedByTokenHash { get; set; }

    public string? RevokedReason { get; set; }

    public virtual ApplicationUser User { get; set; } = null!;
}
