using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using MiniCrm.Application.DTO;
using MiniCrm.Application.Helpers;
using MiniCrm.Core.Exceptions;
using MiniCrm.Infrastructure.Persistence;
using MiniCrm.Infrastructure.Persistence.Entities;

namespace MiniCrm.Application.Services;

public interface IContactService
{
    Task<PagedResult<ContactDto>> ListAsync(Guid userId, int businessId, string? q, int page, int pageSize, CancellationToken ct);
    Task<ContactDto> GetAsync(Guid userId, int businessId, int contactId, CancellationToken ct);
    Task<ContactDto> CreateAsync(Guid userId, int businessId, SaveContactDto dto, CancellationToken ct);
    Task<ContactDto> UpdateAsync(Guid userId, int businessId, int contactId, SaveContactDto dto, CancellationToken ct);
    Task DeleteAsync(Guid userId, int businessId, int contactId, CancellationToken ct);
}

public sealed class ContactService(AppDbContext db, BusinessAccess access) : IContactService
{
    private static readonly Expression<Func<Contact, ContactDto>> Project = c => new ContactDto(
        c.Id, c.FirstName, c.LastName, c.Email, c.Phone, c.CompanyId, c.AddressLine, c.City,
        c.PostalCode, c.Country, c.ContactType, c.ContactSource, c.CreatedAtUtc, c.UpdatedAtUtc, c.RowVersion);

    private static readonly Func<Contact, ContactDto> ToDto = Project.Compile();

    // Every query below filters by BusinessId AND the membership check. Id alone is an IDOR.
    private IQueryable<Contact> Scope(int businessId) =>
        db.Set<Contact>().Where(c => c.BusinessId == businessId && !c.IsDeleted);

    public async Task<PagedResult<ContactDto>> ListAsync(Guid userId, int businessId, string? q, int page, int pageSize, CancellationToken ct)
    {
        await access.RequireAsync(userId, businessId, false, ct);
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var query = Scope(businessId).AsNoTracking();
        if (!string.IsNullOrWhiteSpace(q))
        {
            var t = q.Trim();
            if (t.Length > 100) t = t[..100];
            query = query.Where(c =>
                c.FirstName.Contains(t) || c.LastName.Contains(t) ||
                (c.Email != null && c.Email.Contains(t)) ||
                (c.Phone != null && c.Phone.Contains(t)));
        }

        var total = await query.CountAsync(ct);
        var items = await query
            .OrderBy(c => c.LastName).ThenBy(c => c.FirstName).ThenBy(c => c.Id)
            .Skip((page - 1) * pageSize).Take(pageSize)
            .Select(Project)
            .ToListAsync(ct);

        return new PagedResult<ContactDto>(items, total, page, pageSize);
    }

    public async Task<ContactDto> GetAsync(Guid userId, int businessId, int contactId, CancellationToken ct)
    {
        await access.RequireAsync(userId, businessId, false, ct);
        return await Scope(businessId).AsNoTracking().Where(c => c.Id == contactId).Select(Project).FirstOrDefaultAsync(ct)
            ?? throw new NotFoundDomainException("Contact");
    }

    public async Task<ContactDto> CreateAsync(Guid userId, int businessId, SaveContactDto dto, CancellationToken ct)
    {
        await access.RequireAsync(userId, businessId, true, ct);

        var now = DateTime.UtcNow;
        var c = new Contact
        {
            BusinessId = businessId,
            CreatedByUserId = userId,
            UpdatedByUserId = userId, // non-nullable on your entity: Guid.Empty would violate the FK
            CreatedAtUtc = now
        };
        await ApplyAsync(c, dto, businessId, ct);

        db.Add(c);
        await db.SaveChangesAsync(ct);
        return ToDto(c);
    }

    public async Task<ContactDto> UpdateAsync(Guid userId, int businessId, int contactId, SaveContactDto dto, CancellationToken ct)
    {
        await access.RequireAsync(userId, businessId, true, ct);
        if (dto.RowVersion is not { Length: > 0 }) throw new ValidationDomainException("RowVersion is required.");

        var c = await Scope(businessId).FirstOrDefaultAsync(x => x.Id == contactId, ct)
            ?? throw new NotFoundDomainException("Contact");

        await ApplyAsync(c, dto, businessId, ct);
        c.UpdatedByUserId = userId;
        c.UpdatedAtUtc = DateTime.UtcNow;
        db.Entry(c).Property(x => x.RowVersion).OriginalValue = dto.RowVersion;

        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateConcurrencyException)
        {
            throw new ConflictDomainException("This contact was changed by someone else. Reload and try again.");
        }
        return ToDto(c);
    }

    public async Task DeleteAsync(Guid userId, int businessId, int contactId, CancellationToken ct)
    {
        var m = await access.RequireAsync(userId, businessId, true, ct);
        if (!PermsHelper.CanDeleteContact(m.Role)) throw new ForbiddenDomainException("Only owners and managers can delete contacts.");

        var c = await Scope(businessId).FirstOrDefaultAsync(x => x.Id == contactId, ct)
            ?? throw new NotFoundDomainException("Contact");

        var now = DateTime.UtcNow;
        c.IsDeleted = true;
        c.DeletedAtUtc = now;
        c.UpdatedAtUtc = now;
        c.UpdatedByUserId = userId;
        await db.SaveChangesAsync(ct);
    }

    private async Task ApplyAsync(Contact c, SaveContactDto i, int businessId, CancellationToken ct)
    {
        c.FirstName = TextHelper.Required(i.FirstName, "First name", 1, 100);
        c.LastName = TextHelper.Required(i.LastName, "Last name", 1, 100);
        c.Email = TextHelper.Email(i.Email);
        c.Phone = TextHelper.Optional(i.Phone, "Phone", 30);
        c.AddressLine = TextHelper.Optional(i.AddressLine, "Address", 200);
        c.City = TextHelper.Optional(i.City, "City", 100);
        c.PostalCode = TextHelper.Optional(i.PostalCode, "Postal code", 20);
        c.Country = TextHelper.Optional(i.Country, "Country", 100);

        if (!Enum.IsDefined(i.ContactType) || !Enum.IsDefined(i.ContactSource))
            throw new ValidationDomainException("Invalid contact type or source.");
        c.ContactType = i.ContactType;
        c.ContactSource = i.ContactSource;

        // A CompanyId from another tenant would silently link two businesses' data.
        if (i.CompanyId is int companyId && !await db.Set<Company>().AnyAsync(x => x.Id == companyId && x.BusinessId == businessId, ct))
            throw new ValidationDomainException("Company not found in this business.");
        c.CompanyId = i.CompanyId;
    }
}