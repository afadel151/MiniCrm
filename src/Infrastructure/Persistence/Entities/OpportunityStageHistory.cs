using System;
using System.Collections.Generic;
using MiniCrm.Infrastructure.Identity;
namespace MiniCrm.Infrastructure.Persistence.Entities;

public partial class OpportunityStageHistory
{
    public int Id { get; set; }

    public int OpportunityId { get; set; }

    public int? FromStageId { get; set; }

    public int ToStageId { get; set; }

    public Guid ChangedByUserId { get; set; }

    public DateTime ChangedAtUtc { get; set; }

    public virtual ApplicationUser ChangedByUser { get; set; } = null!;

    public virtual PipelineStage? FromStage { get; set; }

    public virtual Opportunity Opportunity { get; set; } = null!;

    public virtual PipelineStage ToStage { get; set; } = null!;
}
