using MiniCrm.Core.Enums;
using MiniCrm.Infrastructure.Identity;
namespace MiniCrm.Infrastructure.Persistence.Entities;

public partial class Reminder
{
    public int Id { get; set; }

    public int ContactId { get; set; }

    public int? OpportunityId { get; set; }

    public Guid AssignedUserId { get; set; }

    public Guid CreatedByUserId { get; set; }

    public InteractionType InteractionType { get; set; }

    public string Title { get; set; } = null!;

    public string? Notes { get; set; }

    public DateTime DueAtUtc { get; set; }

    public ReminderStatus Status { get; set; }

    public DateTime? NotifiedAtUtc { get; set; }

    public DateTime? CompletedAtUtc { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public byte[] RowVersion { get; set; } = null!;

    public virtual ApplicationUser AssignedUser { get; set; } = null!;

    public virtual Contact Contact { get; set; } = null!;

    public virtual ApplicationUser CreatedByUser { get; set; } = null!;

    public virtual Opportunity? Opportunity { get; set; }
}
