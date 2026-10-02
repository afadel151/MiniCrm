using MiniCrm.Core.Enums;
using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Infrastructure.Persistence.Entities;


public class BusinessInvitation
{
    public int Id { get; set; }
    public int BusinessId { get; set; }
    public Business Business { get; set; } = null!;
    public string Email { get; set; } = null!;            // lowercased, as typed by the inviter
    public string NormalizedEmail { get; set; } = null!;  // upper-invariant, used for matching
    public BusinessMemberRole Role { get; set; }
    public string TokenHash { get; set; } = null!;        // hex SHA-256 of the emailed token; the raw token is never stored
    public InvitationStatus Status { get; set; }
    public Guid InvitedByUserId { get; set; }
    public ApplicationUser InvitedByUser { get; set; } = null!;
    public DateTime CreatedAtUtc { get; set; }
    public DateTime ExpiresAtUtc { get; set; }
    public DateTime? AcceptedAtUtc { get; set; }
    public Guid? AcceptedByUserId { get; set; }
    public DateTime? RevokedAtUtc { get; set; }
}