using System;
using System.Collections.Generic;
using MiniCrm.Infrastructure.Identity;
namespace MiniCrm.Infrastructure.Persistence.Entities;

public partial class Opportunity
{
    public int Id { get; set; }

    public string Title { get; set; } = null!;

    public int ContactId { get; set; }

    public Guid OwnerUserId { get; set; }

    public int StageId { get; set; }

    public decimal Amount { get; set; }

    public byte Probability { get; set; }

    public DateOnly? ExpectedCloseDate { get; set; }

    public DateTime? ClosedAtUtc { get; set; }

    public string? LostReason { get; set; }

    public string? Description { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public Guid CreatedByUserId { get; set; }

    public DateTime? UpdatedAtUtc { get; set; }

    public Guid? UpdatedByUserId { get; set; }

    public bool IsDeleted { get; set; }

    public DateTime? DeletedAtUtc { get; set; }

    public byte[] RowVersion { get; set; } = null!;

    public virtual Contact Contact { get; set; } = null!;

    public virtual ApplicationUser CreatedByUser { get; set; } = null!;

    public virtual ICollection<Interaction> Interactions { get; set; } = new List<Interaction>();

    public virtual ICollection<OpportunityStageHistory> OpportunityStageHistories { get; set; } = new List<OpportunityStageHistory>();

    public virtual ApplicationUser OwnerUser { get; set; } = null!;

    public virtual ICollection<Reminder> Reminders { get; set; } = new List<Reminder>();

    public virtual PipelineStage Stage { get; set; } = null!;

    public virtual ApplicationUser? UpdatedByUser { get; set; }
}
