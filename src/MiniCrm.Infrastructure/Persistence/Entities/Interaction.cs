using System;
using System.Collections.Generic;
using MiniCrm.Core.Enums;
using MiniCrm.Infrastructure.Identity;
namespace MiniCrm.Infrastructure.Persistence.Entities;

public partial class Interaction
{
    public int Id { get; set; }

    public int ContactId { get; set; }

    public int? OpportunityId { get; set; }

    public Guid UserId { get; set; }

    public InteractionType InteractionType { get; set; }

    public DateTime OccurredAtUtc { get; set; }

    public string? Subject { get; set; }

    public string? Notes { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? UpdatedAtUtc { get; set; }

    public byte[] RowVersion { get; set; } = null!;

    public virtual Contact Contact { get; set; } = null!;

    public virtual Opportunity? Opportunity { get; set; }

    public virtual ApplicationUser User { get; set; } = null!;
}
