using System;
using System.Collections.Generic;
namespace MiniCrm.Infrastructure.Persistence.Entities;

public partial class PipelineStage
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public int SortOrder { get; set; }

    public byte DefaultProbability { get; set; }

    public bool IsWon { get; set; }

    public bool IsLost { get; set; }

    public bool IsActive { get; set; }

    public virtual ICollection<Opportunity> Opportunities { get; set; } = new List<Opportunity>();

    public virtual ICollection<OpportunityStageHistory> OpportunityStageHistoryFromStages { get; set; } = new List<OpportunityStageHistory>();

    public virtual ICollection<OpportunityStageHistory> OpportunityStageHistoryToStages { get; set; } = new List<OpportunityStageHistory>();
}
