using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Infrastructure.Persistence.Entities;

/// <summary>Business rates a Client. The rating belongs to the Business (tenant), not to
/// whichever staff member submitted it — RatedByUserId is kept for audit only.</summary>
public class ClientRating
{
    public int Id { get; set; }

    public int BusinessId { get; set; }
    public Business Business { get; set; } = null!;

    public Guid ClientUserId { get; set; }
    public ApplicationUser ClientUser { get; set; } = null!;

    public Guid RatedByUserId { get; set; }              // audit trail only, not the rating's identity
    public ApplicationUser RatedByUser { get; set; } = null!;

    public byte Stars { get; set; }          // 1-5, CHECK constraint
    public string? Comment { get; set; }

    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
}
