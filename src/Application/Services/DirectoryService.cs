using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using MiniCrm.Application.DTO;
using MiniCrm.Core.Enums;
using MiniCrm.Infrastructure.Identity;
using MiniCrm.Infrastructure.Persistence;
using MiniCrm.Infrastructure.Persistence.Entities;

namespace MiniCrm.Application.Services;

public interface IDirectoryService
{
    Task<PagedResult<PublicBusinessDto>> SearchAsync(string? q, BusinessDomain? domain, int page, int pageSize, CancellationToken ct);
    Task<PublicBusinessDto> GetAsync(int businessId, CancellationToken ct);
    Task<PagedResult<RatingView>> ListRatingsAsync(int businessId, int page, int pageSize, CancellationToken ct);
    Task<RatingView> RateAsync(Guid clientId, int businessId, RatingDto dto, CancellationToken ct);
    Task DeleteRatingAsync(Guid clientId, int businessId, CancellationToken ct);
}

public sealed class DirectoryService(AppDbContext db) : IDirectoryService
{
    private static readonly Expression<Func<Business, PublicBusinessDto>> ToPublic = b => new PublicBusinessDto(
        b.Id, b.Name, b.Description, b.Website, b.Adress, b.Domain,
        b.RatingsReceived.Average(r => (double?)r.Stars),
        b.RatingsReceived.Count());

    private IQueryable<Business> Visible() =>
        db.Set<Business>().AsNoTracking().Where(b => b.IsActive && !b.IsDeleted);

    private static string Reviewer(string first, string last) =>
        last.Length > 0 ? $"{first} {last[0]}." : first; 

    public async Task<PagedResult<PublicBusinessDto>> SearchAsync(string? q, BusinessDomain? domain, int page, int pageSize, CancellationToken ct)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 50);

        var query = Visible();
        if (domain is not null) query = query.Where(b => b.Domain == domain);
        if (!string.IsNullOrWhiteSpace(q))
        {
            var t = q.Trim();
            if (t.Length > 100) t = t[..100];
            query = query.Where(b => b.Name.Contains(t) || (b.Description != null && b.Description.Contains(t)));
        }

        var total = await query.CountAsync(ct);
        var items = await query
            .OrderBy(b => b.Name).ThenBy(b => b.Id)
            .Skip((page - 1) * pageSize).Take(pageSize)
            .Select(ToPublic)
            .ToListAsync(ct);

        return new PagedResult<PublicBusinessDto>(items, total, page, pageSize);
    }

    public async Task<PublicBusinessDto> GetAsync(int businessId, CancellationToken ct) =>
        await Visible().Where(b => b.Id == businessId).Select(ToPublic).FirstOrDefaultAsync(ct)
        ?? throw new NotFoundDomainException("Business");

    public async Task<PagedResult<RatingView>> ListRatingsAsync(int businessId, int page, int pageSize, CancellationToken ct)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 50);

        if (!await Visible().AnyAsync(b => b.Id == businessId, ct)) throw new NotFoundDomainException("Business");

        var query = db.Set<BusinessRating>().AsNoTracking().Where(r => r.BusinessId == businessId);
        var total = await query.CountAsync(ct);
        var rows = await query
            .OrderByDescending(r => r.CreatedAtUtc).ThenByDescending(r => r.Id)
            .Skip((page - 1) * pageSize).Take(pageSize)
            .Select(r => new
            {
                r.Id, r.Stars, r.Comment,
                r.ClientUser.FirstName, r.ClientUser.LastName,
                r.CreatedAtUtc, r.UpdatedAtUtc
            })
            .ToListAsync(ct);

        var items = rows.Select(r => new RatingView(r.Id, r.Stars, r.Comment, Reviewer(r.FirstName, r.LastName), r.CreatedAtUtc, r.UpdatedAtUtc)).ToList();
        return new PagedResult<RatingView>(items, total, page, pageSize);
    }

    public async Task<RatingView> RateAsync(Guid clientId, int businessId, RatingDto dto, CancellationToken ct)
    {
        if (dto.Stars is < 1 or > 5) throw new ValidationDomainException("Stars must be between 1 and 5.");
        var comment = Text.Optional(dto.Comment, "Comment", 1000);

        if (!await Visible().AnyAsync(b => b.Id == businessId, ct)) throw new NotFoundDomainException("Business");

        if (await db.Set<BusinessMembership>().AnyAsync(m => m.BusinessId == businessId && m.UserId == clientId && m.IsActive, ct))
            throw new ForbiddenDomainException("You cannot rate a business you work for.");

        var now = DateTime.UtcNow;
        var rating = await db.Set<BusinessRating>()
            .FirstOrDefaultAsync(r => r.BusinessId == businessId && r.ClientUserId == clientId, ct);

        if (rating is null)
        {
            rating = new BusinessRating { BusinessId = businessId, ClientUserId = clientId, CreatedAtUtc = now };
            db.Add(rating);
        }
        else
        {
            rating.UpdatedAtUtc = now;
        }
        rating.Stars = dto.Stars;
        rating.Comment = comment;

        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException ex) when (Text.IsUniqueViolation(ex))
        {
            throw new ConflictDomainException("Your rating was being saved twice. Try again.");
        }

        var u = await db.Set<ApplicationUser>().AsNoTracking()
            .Where(x => x.Id == clientId).Select(x => new { x.FirstName, x.LastName }).SingleAsync(ct);

        return new RatingView(rating.Id, rating.Stars, rating.Comment, Reviewer(u.FirstName, u.LastName), rating.CreatedAtUtc, rating.UpdatedAtUtc);
    }

    public async Task DeleteRatingAsync(Guid clientId, int businessId, CancellationToken ct)
    {
        var deleted = await db.Set<BusinessRating>()
            .Where(r => r.BusinessId == businessId && r.ClientUserId == clientId)
            .ExecuteDeleteAsync(ct);
        if (deleted == 0) throw new NotFoundDomainException("Rating");
    }
}