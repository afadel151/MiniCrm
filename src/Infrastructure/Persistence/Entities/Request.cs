using MiniCrm.Core.Enums;
using MiniCrm.Infrastructure.Identity;
namespace MiniCrm.Infrastructure.Persistence.Entities;

public partial class Request
{
    public int Id { get; set; }


    public string Title { get; set; } = null!;

    public string? Description { get; set; }
    public string? Notes { get; set; }

    public int? ContactId { get; set; }

    // public int? OpportunityId { get; set; }
    public Guid CreatedByUserId { get; set; }


    public RequestOrigin Origin { get; set; } = RequestOrigin.Other;
    public RequestStatus Status { get; set; } = RequestStatus.New;
    public RequestPriority Priority { get; set; } = RequestPriority.Medium;

    public DateTime DueAtUtc { get; set; }

    public bool IsDeleted { get; set; }
    public DateTime? DeletedAtUtc { get; set; }

    public byte[] RowVersion { get; set; } = null!;


    public virtual Contact Contact { get; set; } = null!;

    public virtual ApplicationUser CreatedByUser { get; set; } = null!;
}
