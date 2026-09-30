using MiniCrm.Core.Enums;
using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Infrastructure.Persistence.Entities;

public class BusinessMembership
{
    public int Id { get; set; }

    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public int BusinessId { get; set; }
    public Business Business { get; set; } = null!;

    public BusinessMemberRole Role { get; set; }

    public bool IsPrimaryOwner { get; set; }

    public bool IsActive { get; set; } = true;  
    public DateTime CreatedAtUtc { get; set; }
}
