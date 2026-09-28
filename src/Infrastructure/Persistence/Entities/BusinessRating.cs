using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Infrastructure.Persistence.Entities;

/// <summary>Client rates a Business. One rating per (Business, Client) pair — editable, not
/// re-postable, matching the old SellerRating's unique-index pattern.</summary>
public class BusinessRating
{
    public int Id { get; set; }

    public int BusinessId { get; set; }
    public Business Business { get; set; } = null!;

    public Guid ClientUserId { get; set; }
    public ApplicationUser ClientUser { get; set; } = null!;

    public byte Stars { get; set; }          // 1-5, CHECK constraint
    public string? Comment { get; set; }

    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
}
