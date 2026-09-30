using System.Net.Mail;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using MiniCrm.Core.Enums;
using MiniCrm.Infrastructure.Persistence;
using MiniCrm.Infrastructure.Persistence.Entities;

namespace MiniCrm.Application.Services;

public abstract class DomainException(int status, string title, string detail) : Exception(detail)
{
    public int Status { get; } = status;
    public string Title { get; } = title;
}

public sealed class NotFoundDomainException(string what) : DomainException(404, "Not found", $"{what} not found.");
public sealed class ForbiddenDomainException(string detail = "You are not allowed to do this.") : DomainException(403, "Forbidden", detail);
public sealed class ConflictDomainException(string detail) : DomainException(409, "Conflict", detail);
public sealed class ValidationDomainException(string detail) : DomainException(400, "Invalid request", detail);

/// <summary>
/// The single place that answers "may this user touch this business?". It reads the DB on every
/// call, so removing a member or disabling an account takes effect immediately, not when the JWT expires.
/// </summary>
public sealed class BusinessAccess(AppDbContext db)
{
    public async Task<BusinessMembership> RequireAsync(Guid userId, int businessId, bool forWrite, CancellationToken ct)
    {
        // 404 and not 403: non-members must not learn that a business id exists.
        var m = await db.Set<BusinessMembership>()
            .Include(x => x.Business)
            .FirstOrDefaultAsync(x =>
                x.BusinessId == businessId &&
                x.UserId == userId &&
                x.IsActive &&
                x.User.IsActive &&
                !x.Business.IsDeleted, ct) ?? throw new NotFoundDomainException("Business");
        if (forWrite && !m.Business.IsActive) throw new ForbiddenDomainException("This business is suspended.");
        return m;
    }
}

/// <summary>Adjust the role names here if your BusinessMemberRole enum differs.</summary>
public static class Perms
{
    public static bool CanEditBusiness(BusinessMemberRole r) =>
        r is  BusinessMemberRole.Manager;

    public static bool CanDeleteContact(BusinessMemberRole r) =>
        r is  BusinessMemberRole.Manager;

    /// <summary>Owners manage anyone except the primary owner (checked by callers). Managers manage Staff only.</summary>
    public static bool CanManage(BusinessMemberRole actor, BusinessMemberRole target) => actor switch
    {
        BusinessMemberRole.Manager => target == BusinessMemberRole.Staff,
        _ => false
    };
}

public static class Text
{
    public static string Required(string? v, string field, int min, int max)
    {
        var s = string.Join(' ', (v ?? "").Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
        if (s.Length < min || s.Length > max)
            throw new ValidationDomainException($"{field} must be between {min} and {max} characters.");
        return s;
    }

    public static string? Optional(string? v, string field, int max)
    {
        var s = v?.Trim();
        if (string.IsNullOrEmpty(s)) return null;
        if (s.Length > max) throw new ValidationDomainException($"{field} must be at most {max} characters.");
        return s;
    }

    /// <summary>Only http(s) survives: a stored "javascript:" URL rendered as a link is stored XSS.</summary>
    public static string? Website(string? v)
    {
        var s = Optional(v, "Website", 200);
        if (s is null) return null;
        if (!s.Contains("://")) s = "https://" + s;
        if (!Uri.TryCreate(s, UriKind.Absolute, out var u) || u.Scheme is not ("http" or "https") || string.IsNullOrEmpty(u.Host))
            throw new ValidationDomainException("Website must be a valid http(s) address.");
        return u.AbsoluteUri.TrimEnd('/');
    }

    public static string? Email(string? v)
    {
        var s = Optional(v, "Email", 254);
        if (s is null) return null;
        if (!MailAddress.TryCreate(s, out var a) || a.Address != s)
            throw new ValidationDomainException("Email is not valid.");
        return s.ToLowerInvariant();
    }

    public static bool IsUniqueViolation(DbUpdateException ex) =>
        ex.InnerException is SqlException { Number: 2601 or 2627 };
}