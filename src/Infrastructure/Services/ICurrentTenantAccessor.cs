namespace MiniCrm.Infrastructure.Services;

/// <summary>
/// Reads the current request's tenant scope from the validated JWT. Implemented in the Api
/// project (reads ClaimsPrincipal), NOT in Infrastructure — Infrastructure must stay
/// framework-agnostic per your existing convention (IAuditService lives in Core.Services too).
/// </summary>
public interface ICurrentTenantAccessor
{
    /// <summary>Null for SiteAdmin and EndClient — they have no tenant.</summary>
    int? BusinessId { get; }

    bool IsSiteAdmin { get; }

    Guid? UserId { get; }
}
