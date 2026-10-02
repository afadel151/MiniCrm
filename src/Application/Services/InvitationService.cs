using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MiniCrm.Application.DTO;
using MiniCrm.Application.Helpers;
using MiniCrm.Core.Enums;
using MiniCrm.Core.Exceptions;
using MiniCrm.Core.Services;
using MiniCrm.Infrastructure.Identity;
using MiniCrm.Infrastructure.Persistence;
using MiniCrm.Infrastructure.Persistence.Entities;

namespace MiniCrm.Application.Services;

public sealed class GoneDomainException(string detail) : DomainException(410, "Gone", detail);
public sealed class RateLimitedDomainException(string detail) : DomainException(429, "Too many requests", detail);

public sealed class InvitationOptions
{
    public const string Section = "Invitations";

    /// <summary>Frontend origin, e.g. https://app.example.com. Never build it from the request Host header (link poisoning).</summary>
    public string AppBaseUrl { get; set; } = "";
    public int ExpiryDays { get; set; } = 7;
    public int MaxPendingPerBusiness { get; set; } = 50;
    public int MaxPerBusinessPerDay { get; set; } = 20;
}

public sealed record InvitationEmail(string To, string BusinessName, string InviterName, BusinessMemberRole Role, string Link, DateTime ExpiresAtUtc);

/// <summary>You must implement this for production (SMTP or a provider). HTML-encode BusinessName and InviterName: they are user-controlled.</summary>
public interface IInvitationEmailSender
{
    Task SendAsync(InvitationEmail mail, CancellationToken ct);
}

/// <summary>Development only. It logs the link, which in production would leak every invitation token.</summary>
public sealed class DevLogInvitationEmailSender(ILogger<DevLogInvitationEmailSender> logger) : IInvitationEmailSender
{
    public Task SendAsync(InvitationEmail mail, CancellationToken ct)
    {
        logger.LogWarning("DEV invitation for {To} ({Business}, {Role}): {Link}", mail.To, mail.BusinessName, mail.Role, mail.Link);
        return Task.CompletedTask;
    }
}

public static class InvitationPerms
{
    /// <summary>The primary owner invites any role. A Manager invites Staff only. Everyone else cannot invite.</summary>
    public static bool CanInvite(BusinessMembership m, BusinessMemberRole target) =>
        m.IsPrimaryOwner || (m.Role == BusinessMemberRole.Manager && target == BusinessMemberRole.Staff);

    public static bool CanSeeInvitations(BusinessMembership m) =>
        m.IsPrimaryOwner || m.Role == BusinessMemberRole.Manager;
}

public interface IInvitationService
{
    Task<InvitationCreatedDto> CreateAsync(Guid userId, int businessId, CreateInvitationDto dto, CancellationToken ct);
    Task<IReadOnlyList<InvitationListItemDto>> ListAsync(Guid userId, int businessId, CancellationToken ct);
    Task RevokeAsync(Guid userId, int businessId, int invitationId, CancellationToken ct);
    Task<InvitationPreviewDto> PreviewAsync(string token, CancellationToken ct);
    Task<AcceptInvitationResult> AcceptAsync(Guid userId, string token, CancellationToken ct);
    Task<AcceptInvitationResult> RegisterAndAcceptAsync(RegisterStaffRequest request, CancellationToken ct);
}

public sealed class InvitationService(
    AppDbContext db,
    BusinessAccess access,
    UserManager<ApplicationUser> users,
    IRoleHelper roleHelper,
    IInvitationEmailSender sender,
    IOptions<InvitationOptions> options,
    ILogger<InvitationService> logger) : IInvitationService
{
    private readonly InvitationOptions _opt = options.Value;


    private static string NewToken() =>
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static string Hash(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
    private static string Normalize(string email) => email.Trim().ToUpperInvariant();

    private static string Mask(string email)
    {
        var at = email.IndexOf('@');
        return at < 1 ? "***" : email[0] + "***" + email[at..];
    }

    private static string ShortName(string first, string last) => last.Length > 0 ? $"{first} {last[0]}." : first;

    private static string Reason(InvitationStatus s) => s switch
    {
        InvitationStatus.Accepted => "This invitation has already been used.",
        InvitationStatus.Expired => "This invitation has expired. Ask for a new one.",
        _ => "This invitation is no longer valid. Ask for a new one."
    };

    private async Task<BusinessInvitation?> FindByTokenAsync(string? token, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(token) || token.Length > 100) return null;
        var hash = Hash(token.Trim());
        return await db.Set<BusinessInvitation>().AsNoTracking()
            .Include(i => i.Business)
            .Include(i => i.InvitedByUser)
            .FirstOrDefaultAsync(i => i.TokenHash == hash, ct);
    }

    /// <summary>Stored status plus everything that can invalidate a pending invitation after it was sent.</summary>
    private async Task<InvitationStatus> EffectiveStatusAsync(BusinessInvitation inv, CancellationToken ct)
    {
        if (inv.Status != InvitationStatus.Pending) return inv.Status;
        if (inv.ExpiresAtUtc <= DateTime.UtcNow) return InvitationStatus.Expired;
        if (inv.Business.IsDeleted || !inv.Business.IsActive) return InvitationStatus.Revoked;

        // The inviter must still be an active member who may invite this role, or a removed manager's old links keep working.
        var inviter = await db.Set<BusinessMembership>().AsNoTracking()
            .FirstOrDefaultAsync(m => m.BusinessId == inv.BusinessId && m.UserId == inv.InvitedByUserId && m.IsActive && m.User.IsActive, ct);

        return inviter is not null && InvitationPerms.CanInvite(inviter, inv.Role)
            ? InvitationStatus.Pending
            : InvitationStatus.Revoked;
    }

    // ---------- staff side ----------

    public async Task<InvitationCreatedDto> CreateAsync(Guid userId, int businessId, CreateInvitationDto dto, CancellationToken ct)
    {
        logger.LogInformation("Dto: {Dto}",dto);
        var actor = await access.RequireAsync(userId, businessId, true, ct);
        if (!Enum.IsDefined(dto.Role)) throw new ValidationDomainException("Invalid role.");
        Console.WriteLine("role"+ InvitationPerms.CanInvite(actor, dto.Role));
        if (!InvitationPerms.CanInvite(actor, dto.Role)) throw new ForbiddenDomainException("Your role cannot invite that role.");

        var email = TextHelper.Email(dto.Email) ?? throw new ValidationDomainException("Email is required.");
        var normalized = Normalize(email);

        // Only reveals what the inviter already sees in the team list. Whether an account exists is never disclosed here.
        if (await db.Set<BusinessMembership>().AnyAsync(m => m.BusinessId == businessId && m.IsActive && m.User.NormalizedEmail == normalized, ct))
            throw new ConflictDomainException("This person is already on your team.");

        var now = DateTime.UtcNow;

        var pending = await db.Set<BusinessInvitation>()
            .CountAsync(i => i.BusinessId == businessId && i.Status == InvitationStatus.Pending && i.ExpiresAtUtc > now, ct);
        if (pending >= _opt.MaxPendingPerBusiness)
            throw new ConflictDomainException("Too many pending invitations. Revoke some first.");

        var sentToday = await db.Set<BusinessInvitation>()
            .CountAsync(i => i.BusinessId == businessId && i.CreatedAtUtc > now.AddDays(-1), ct);
        if (sentToday >= _opt.MaxPerBusinessPerDay)
            throw new RateLimitedDomainException("Daily invitation limit reached. Try again tomorrow.");

        if (string.IsNullOrWhiteSpace(_opt.AppBaseUrl))
            throw new InvalidOperationException("Invitations:AppBaseUrl is not configured.");

        var businessName = actor.Business.Name;
        var inviter = await db.Set<ApplicationUser>().AsNoTracking()
            .Where(u => u.Id == userId).Select(u => new { u.FirstName, u.LastName }).SingleAsync(ct);

        var token = NewToken();
        var invitation = new BusinessInvitation
        {
            BusinessId = businessId,
            Email = email,
            NormalizedEmail = normalized,
            Role = dto.Role,
            TokenHash = Hash(token),
            Status = InvitationStatus.Pending,
            InvitedByUserId = userId,
            CreatedAtUtc = now,
            ExpiresAtUtc = now.AddDays(_opt.ExpiryDays)
        };

        try
        {
            var strategy = db.Database.CreateExecutionStrategy();
            await strategy.ExecuteAsync(async () =>
            {
                db.ChangeTracker.Clear(); // a retry must not see entities from the failed attempt
                await using var tx = await db.Database.BeginTransactionAsync(ct);

                // Re-inviting replaces the previous pending link for the same email (this is also "resend").
                await db.Set<BusinessInvitation>()
                    .Where(i => i.BusinessId == businessId && i.NormalizedEmail == normalized && i.Status == InvitationStatus.Pending)
                    .ExecuteUpdateAsync(s => s
                        .SetProperty(i => i.Status, InvitationStatus.Revoked)
                        .SetProperty(i => i.RevokedAtUtc, now), ct);

                db.Add(invitation);
                await db.SaveChangesAsync(ct);
                await tx.CommitAsync(ct);
            });
        }
        catch (DbUpdateException ex) when (TextHelper.IsUniqueViolation(ex))
        {
            throw new ConflictDomainException("An invitation for this email is being created right now. Try again.");
        }

        var link = $"{_opt.AppBaseUrl.TrimEnd('/')}/invite#{token}"; // fragment: never sent to servers, never in access logs
        var emailSent = false;
        try
        {
            await sender.SendAsync(new InvitationEmail(email, businessName, ShortName(inviter.FirstName, inviter.LastName), dto.Role, link, invitation.ExpiresAtUtc), ct);
            emailSent = true;
        }
        catch (Exception ex)
        {
            // The invitation stays valid. The manager sees emailSent=false and can re-invite to resend.
            logger.LogError(ex, "Invitation email failed for invitation {InvitationId}", invitation.Id);
        }

        return new InvitationCreatedDto(invitation.Id, email, dto.Role, invitation.ExpiresAtUtc, emailSent);
    }

    public async Task<IReadOnlyList<InvitationListItemDto>> ListAsync(Guid userId, int businessId, CancellationToken ct)
    {
        var actor = await access.RequireAsync(userId, businessId, false, ct);
        if (!InvitationPerms.CanSeeInvitations(actor)) throw new ForbiddenDomainException();

        var now = DateTime.UtcNow;
        var rows = await db.Set<BusinessInvitation>().AsNoTracking()
            .Where(i => i.BusinessId == businessId)
            .OrderByDescending(i => i.CreatedAtUtc).ThenByDescending(i => i.Id)
            .Take(100)
            .Select(i => new { i.Id, i.Email, i.Role, i.Status, i.CreatedAtUtc, i.ExpiresAtUtc, i.InvitedByUser.FirstName, i.InvitedByUser.LastName })
            .ToListAsync(ct);

        return rows.Select(r => new InvitationListItemDto(
            r.Id, r.Email, r.Role,
            r.Status == InvitationStatus.Pending && r.ExpiresAtUtc <= now ? InvitationStatus.Expired : r.Status,
            r.CreatedAtUtc, r.ExpiresAtUtc, ShortName(r.FirstName, r.LastName))).ToList();
    }

    public async Task RevokeAsync(Guid userId, int businessId, int invitationId, CancellationToken ct)
    {
        var actor = await access.RequireAsync(userId, businessId, false, ct);
        if (!InvitationPerms.CanSeeInvitations(actor)) throw new ForbiddenDomainException();

        // BusinessId in the filter: an invitation id from another business must not resolve.
        var inv = await db.Set<BusinessInvitation>().AsNoTracking()
            .FirstOrDefaultAsync(i => i.Id == invitationId && i.BusinessId == businessId, ct)
            ?? throw new NotFoundDomainException("Invitation");

        if (!InvitationPerms.CanInvite(actor, inv.Role)) throw new ForbiddenDomainException();
        if (inv.Status == InvitationStatus.Accepted) throw new ConflictDomainException("Already accepted. Remove the member instead.");

        var now = DateTime.UtcNow;
        await db.Set<BusinessInvitation>()
            .Where(i => i.Id == invitationId && i.Status == InvitationStatus.Pending)
            .ExecuteUpdateAsync(s => s
                .SetProperty(i => i.Status, InvitationStatus.Revoked)
                .SetProperty(i => i.RevokedAtUtc, now), ct);
    }

    // ---------- invitee side ----------

    /// <summary>Read-only and anonymous. Never consumes the token, so scanners and prefetchers are harmless.</summary>
    public async Task<InvitationPreviewDto> PreviewAsync(string token, CancellationToken ct)
    {
        var inv = await FindByTokenAsync(token, ct) ?? throw new NotFoundDomainException("Invitation");
        var status = await EffectiveStatusAsync(inv, ct);

        var state = InviteeAccountState.NoAccount;
        if (status == InvitationStatus.Pending) // dead tokens reveal nothing about accounts
        {
            var user = await users.FindByEmailAsync(inv.Email);
            if (user is not null)
            {
                if (await users.IsInRoleAsync(user, AppRoles.Business)) state = InviteeAccountState.BusinessAccount;
                else if (await users.IsInRoleAsync(user, AppRoles.Client)) state = InviteeAccountState.ClientAccount;
                else state = InviteeAccountState.OtherAccount;
            }
        }

        return new InvitationPreviewDto(
            inv.Business.Name,
            ShortName(inv.InvitedByUser.FirstName, inv.InvitedByUser.LastName),
            inv.Role, Mask(inv.Email), status, state, inv.ExpiresAtUtc);
    }

    public async Task<AcceptInvitationResult> AcceptAsync(Guid userId, string token, CancellationToken ct)
    {
        var inv = await FindByTokenAsync(token, ct) ?? throw new NotFoundDomainException("Invitation");

        var user = await users.FindByIdAsync(userId.ToString()) ?? throw new ForbiddenDomainException("Invalid session.");
        if (!user.IsActive) throw new ForbiddenDomainException("Your account is deactivated.");

        if (!await users.IsInRoleAsync(user, AppRoles.Business))
            throw new ForbiddenDomainException("Only business accounts can join a team. This is a personal account; ask for an invitation to a different email.");

        // Compared against the DB email, not the JWT claim, which can be stale.
        if (Normalize(user.Email ?? "") != inv.NormalizedEmail)
            throw new ForbiddenDomainException($"This invitation was sent to {Mask(inv.Email)}. Sign in with that account.");

        return await AcceptCoreAsync(inv.Id, user.Id, ct);
    }

    public async Task<AcceptInvitationResult> RegisterAndAcceptAsync(RegisterStaffRequest request, CancellationToken ct)
    {
        var inv = await FindByTokenAsync(request.Token, ct) ?? throw new NotFoundDomainException("Invitation");

        var status = await EffectiveStatusAsync(inv, ct);
        if (status != InvitationStatus.Pending) throw new GoneDomainException(Reason(status));

        if (await users.FindByEmailAsync(inv.Email) is not null)
            throw new ConflictDomainException("An account already exists for this email. Sign in to accept the invitation.");

        if (!await roleHelper.EnsureRoleExistsAsync(AppRoles.Business))
            throw new InvalidOperationException("Could not ensure the Business role exists.");

        var user = new ApplicationUser
        {
            UserName = inv.Email,
            Email = inv.Email,                       // from the invitation, never from the caller
            FirstName = TextHelper.Required(request.FirstName, "First name", 1, 100),
            LastName = TextHelper.Required(request.LastName, "Last name", 1, 100),
            EmailConfirmed = true,                   // the emailed token proves mailbox control
            IsActive = true,
            MustChangePassword = false,              // they just chose this password
            CreatedAtUtc = DateTime.UtcNow
        };

        var created = await users.CreateAsync(user, request.Password); // a weak password fails here and the token stays unused
        if (!created.Succeeded)
            throw new ValidationDomainException(string.Join("; ", created.Errors.Select(e => e.Description)));

        var roleResult = await roleHelper.SetRoleAsync(user, AppRoles.Business);
        if (!roleResult.Succeeded)
        {
            await users.DeleteAsync(user);
            throw new InvalidOperationException("Could not assign the Business role.");
        }

        try
        {
            return await AcceptCoreAsync(inv.Id, user.Id, ct);
        }
        catch (DomainException ex)
        {
            // The account exists and is usable. Only the membership failed.
            throw new ConflictDomainException($"Your account was created, but the invitation could not be applied: {ex.Message} Sign in and ask for a new invitation.");
        }
    }

    // ---------- the one place a membership is granted from an invitation ----------

    private async Task<AcceptInvitationResult> AcceptCoreAsync(int invitationId, Guid userId, CancellationToken ct)
    {
        try
        {
            var strategy = db.Database.CreateExecutionStrategy();
            return await strategy.ExecuteAsync(async () =>
            {
                db.ChangeTracker.Clear(); // a retry must not see entities from the failed attempt
                var now = DateTime.UtcNow;

                var inv = await db.Set<BusinessInvitation>().AsNoTracking()
                    .Include(i => i.Business)
                    .FirstAsync(i => i.Id == invitationId, ct);

                if (inv.Status == InvitationStatus.Accepted)
                {
                    if (inv.AcceptedByUserId != userId) throw new GoneDomainException(Reason(InvitationStatus.Accepted));
                    return new AcceptInvitationResult(inv.BusinessId, inv.Business.Name, inv.Role, true); // double click: same user, same result
                }

                var effective = await EffectiveStatusAsync(inv, ct);
                if (effective != InvitationStatus.Pending) throw new GoneDomainException(Reason(effective));

                await using var tx = await db.Database.BeginTransactionAsync(ct);

                // Atomic compare-and-set: exactly one caller can consume the invitation.
                var claimed = await db.Set<BusinessInvitation>()
                    .Where(i => i.Id == invitationId && i.Status == InvitationStatus.Pending && i.ExpiresAtUtc > now)
                    .ExecuteUpdateAsync(s => s
                        .SetProperty(i => i.Status, InvitationStatus.Accepted)
                        .SetProperty(i => i.AcceptedAtUtc, now)
                        .SetProperty(i => i.AcceptedByUserId, (Guid?)userId), ct);
                if (claimed == 0) throw new ConflictDomainException("This invitation was just used or revoked.");

                var m = await db.Set<BusinessMembership>()
                    .FirstOrDefaultAsync(x => x.BusinessId == inv.BusinessId && x.UserId == userId, ct);

                var already = m is { IsActive: true };
                if (m is null)
                {
                    m = new BusinessMembership
                    {
                        BusinessId = inv.BusinessId,
                        UserId = userId,
                        Role = inv.Role,
                        IsPrimaryOwner = false,
                        IsActive = true,
                        CreatedAtUtc = now
                    };
                    db.Add(m);
                }
                else if (!m.IsActive)
                {
                    m.IsActive = true; // previously removed: reuse the row, the (BusinessId, UserId) index forbids a second one
                    m.Role = inv.Role;
                }
                // An already-active member keeps their role: accepting never promotes or demotes.

                await db.SaveChangesAsync(ct);
                await tx.CommitAsync(ct);

                return new AcceptInvitationResult(inv.BusinessId, inv.Business.Name, m.Role, already);
            });
        }
        catch (DbUpdateException ex) when (TextHelper.IsUniqueViolation(ex))
        {
            // Two invitations to the same business accepted at the same instant. The transaction rolled back, nothing was consumed.
            throw new ConflictDomainException("Another request is joining you to this business. Reload and check.");
        }
    }
}