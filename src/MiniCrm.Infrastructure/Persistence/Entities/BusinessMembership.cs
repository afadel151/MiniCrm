using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Infrastructure.Persistence.Entities;

/// <summary>
/// Functional tier (Manager/Staff) is a Role/JWT claim — same for every tenant.
/// WHICH tenant is data, from THIS table, carried as a separate "tenant_id" JWT claim.
/// Never conflate the two: role membership tells you what a user can do in general,
/// this row tells you whose data they can touch.
/// </summary>
public enum BusinessMemberRole : byte
{
    Manager = 1,   // old "Admin" — full CRM access within the tenant
    Staff = 2,     // old "User" — limited CRM access within the tenant
}

public class BusinessMembership
{
    public int Id { get; set; }

    public Guid UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public int BusinessId { get; set; }
    public Business Business { get; set; } = null!;

    public BusinessMemberRole Role { get; set; }

    /// <summary>The member who created the tenant. Cannot be removed. Grants NO extra
    /// permission over Manager — confirmed: same permissions, just flagged primary.</summary>
    public bool IsPrimaryOwner { get; set; }

    public bool IsActive { get; set; } = true;   // deactivate a staff member without deleting history
    public DateTime CreatedAtUtc { get; set; }
}
