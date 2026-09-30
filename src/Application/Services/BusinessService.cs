using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using MiniCrm.Application.DTO;
using MiniCrm.Core.Enums;
using MiniCrm.Infrastructure.Identity;
using MiniCrm.Infrastructure.Persistence;
using MiniCrm.Infrastructure.Persistence.Entities;

namespace MiniCrm.Application.Services;

public interface IBusinessService
{
    Task<BusinessInfosResult> ListMineAsync(Guid userId, CancellationToken ct);
    Task<BusinessDetail> CreateAsync(Guid userId, CreateBusinessDto dto, CancellationToken ct);
    Task<BusinessDetail> GetAsync(Guid userId, int businessId, CancellationToken ct);
    Task<BusinessDetail> UpdateAsync(Guid userId, int businessId, UpdateBusinessDto dto, CancellationToken ct);
    Task DeleteAsync(Guid userId, int businessId, CancellationToken ct);
    Task<IReadOnlyList<MemberDto>> ListMembersAsync(Guid userId, int businessId, CancellationToken ct);
    // Task<MemberDto> AddMemberAsync(Guid userId, int businessId, AddMemberDto dto, CancellationToken ct);
    Task ChangeMemberRoleAsync(Guid userId, int businessId, int membershipId, ChangeMemberRoleDto dto, CancellationToken ct);
    Task RemoveMemberAsync(Guid userId, int businessId, int membershipId, CancellationToken ct);
}

public sealed class BusinessService(AppDbContext db, BusinessAccess access) : IBusinessService
{
    private const int MaxOwnedBusinesses = 5; // stops directory spam from one account
    private const string BusinessRole = "Business";

    private static BusinessDetail ToDetail(Business b, BusinessMembership m, int count) => new(
        b.Id, b.Name, b.Description, b.Website, b.Adress, b.Domain, b.IsActive,
        count, m.Role, m.IsPrimaryOwner, b.RowVersion);

    public async Task<BusinessInfosResult> ListMineAsync(Guid userId, CancellationToken ct)
    {
        var infos = await db.Set<BusinessMembership>().AsNoTracking()
            .Where(m => m.UserId == userId && m.IsActive && !m.Business.IsDeleted)
            .OrderBy(m => m.Business.Name)
            .Select(m => new BusinessInfo(
                m.BusinessId,
                m.Business.Name,
                m.Business.IsActive,
                m.Business.Memberships.Count(x => x.IsActive),
                new MembershipInfo(m.Id, m.Role, m.IsActive)))
            .ToListAsync(ct);

        return new BusinessInfosResult(infos);
    }

    public async Task<BusinessDetail> CreateAsync(Guid userId, CreateBusinessDto dto, CancellationToken ct)
    {
        var name = Text.Required(dto.BusinessName, "Name", 2, 150);
        var description = Text.Optional(dto.Description, "Description", 2000);
        var address = Text.Optional(dto.BusinessAdress, "Address", 300);
        var website = Text.Website(dto.Website);
        if (!Enum.IsDefined(dto.BusinessDomain)) throw new ValidationDomainException("Invalid business domain.");

        var owned = await db.Set<BusinessMembership>()
            .CountAsync(m => m.UserId == userId && m.IsPrimaryOwner && m.IsActive && !m.Business.IsDeleted, ct);
        if (owned >= MaxOwnedBusinesses)
            throw new ConflictDomainException($"You can own at most {MaxOwnedBusinesses} businesses.");

        // Friendly message. The filtered unique index is what actually guarantees it.
        if (await db.Set<Business>().AnyAsync(b => !b.IsDeleted && b.Name == name, ct))
            throw new ConflictDomainException("A business with this name already exists.");

        var now = DateTime.UtcNow;
        var business = new Business
        {
            Name = name,
            Description = description,
            Adress = address,
            Website = website,
            Domain = dto.BusinessDomain,
            CreatedAtUtc = now
        };
        var membership = new BusinessMembership
        {
            UserId = userId,
            Role = BusinessMemberRole.Manager,
            IsPrimaryOwner = true,
            IsActive = true,
            CreatedAtUtc = now
        };
        business.Memberships.Add(membership);
        db.Add(business);

        try
        {
            await db.SaveChangesAsync(ct); // business + owner membership in one transaction
        }
        catch (DbUpdateException ex) when (Text.IsUniqueViolation(ex))
        {
            throw new ConflictDomainException("A business with this name already exists.");
        }

        return ToDetail(business, membership, 1);
    }

    public async Task<BusinessDetail> GetAsync(Guid userId, int businessId, CancellationToken ct)
    {
        var m = await access.RequireAsync(userId, businessId, false, ct);
        var count = await db.Set<BusinessMembership>().CountAsync(x => x.BusinessId == businessId && x.IsActive, ct);
        return ToDetail(m.Business, m, count);
    }

    public async Task<BusinessDetail> UpdateAsync(Guid userId, int businessId, UpdateBusinessDto dto, CancellationToken ct)
    {
        var m = await access.RequireAsync(userId, businessId, true, ct);
        if (!Perms.CanEditBusiness(m.Role)) throw new ForbiddenDomainException();
        if (dto.RowVersion is not { Length: > 0 }) throw new ValidationDomainException("RowVersion is required.");
        if (!Enum.IsDefined(dto.BusinessDomain)) throw new ValidationDomainException("Invalid business domain.");

        var b = m.Business;
        var name = Text.Required(dto.BusinessName, "Name", 2, 150);

        if (!string.Equals(name, b.Name, StringComparison.OrdinalIgnoreCase) &&
            await db.Set<Business>().AnyAsync(x => !x.IsDeleted && x.Id != b.Id && x.Name == name, ct))
            throw new ConflictDomainException("A business with this name already exists.");

        b.Name = name;
        b.Description = Text.Optional(dto.Description, "Description", 2000);
        b.Adress = Text.Optional(dto.BusinessAdress, "Address", 300);
        b.Website = Text.Website(dto.Website);
        b.Domain = dto.BusinessDomain;
        b.UpdatedAtUtc = DateTime.UtcNow;
        db.Entry(b).Property(x => x.RowVersion).OriginalValue = dto.RowVersion;

        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateConcurrencyException)
        {
            throw new ConflictDomainException("This business was changed by someone else. Reload and try again.");
        }
        catch (DbUpdateException ex) when (Text.IsUniqueViolation(ex))
        {
            throw new ConflictDomainException("A business with this name already exists.");
        }

        var count = await db.Set<BusinessMembership>().CountAsync(x => x.BusinessId == businessId && x.IsActive, ct);
        return ToDetail(b, m, count);
    }

    public async Task DeleteAsync(Guid userId, int businessId, CancellationToken ct)
    {
        var m = await access.RequireAsync(userId, businessId, false, ct);
        if (!m.IsPrimaryOwner) throw new ForbiddenDomainException("Only the primary owner can delete the business.");

        var now = DateTime.UtcNow;
        m.Business.IsDeleted = true;
        m.Business.DeletedAtUtc = now;
        m.Business.UpdatedAtUtc = now;
        await db.SaveChangesAsync(ct);
    }

    public async Task<IReadOnlyList<MemberDto>> ListMembersAsync(Guid userId, int businessId, CancellationToken ct)
    {
        await access.RequireAsync(userId, businessId, false, ct); // every member can see the team

        return await db.Set<BusinessMembership>().AsNoTracking()
            .Where(m => m.BusinessId == businessId)
            .OrderByDescending(m => m.IsPrimaryOwner).ThenBy(m => m.User.LastName).ThenBy(m => m.Id)
            .Select(m => new MemberDto(
                m.Id, m.UserId, m.User.FirstName + " " + m.User.LastName, m.User.Email ?? "",
                m.Role, m.IsPrimaryOwner, m.IsActive, m.CreatedAtUtc))
            .ToListAsync(ct);
    }

    // public async Task<MemberDto> AddMemberAsync(Guid userId, int businessId, AddMemberDto dto, CancellationToken ct)
    // {
    //     var actor = await access.RequireAsync(userId, businessId, true, ct);
    //     if (!Enum.IsDefined(dto.Role)) throw new ValidationDomainException("Invalid role.");
    //     if (!Perms.CanManage(actor.Role, dto.Role)) throw new ForbiddenDomainException("Your role cannot add members with that role.");

    //     var email = Text.Email(dto.Email) ?? throw new ValidationDomainException("Email is required.");
    //     var target = await users.FindByEmailAsync(email);

    //     // Same message for unknown email and wrong account type, to leak as little as possible.
    //     if (target is null || !target.IsActive || !await users.IsInRoleAsync(target, BusinessRole))
    //         throw new ValidationDomainException("No eligible business account found for that email.");

    //     var existing = await db.Set<BusinessMembership>()
    //         .FirstOrDefaultAsync(x => x.BusinessId == businessId && x.UserId == target.Id, ct);

    //     if (existing is { IsActive: true }) throw new ConflictDomainException("This person is already a member.");

    //     var now = DateTime.UtcNow;
    //     BusinessMembership m;
    //     if (existing is not null)
    //     {
    //         existing.IsActive = true;
    //         existing.Role = dto.Role;
    //         m = existing;
    //     }
    //     else
    //     {
    //         m = new BusinessMembership
    //         {
    //             BusinessId = businessId,
    //             UserId = target.Id,
    //             Role = dto.Role,
    //             IsPrimaryOwner = false,
    //             IsActive = true,
    //             CreatedAtUtc = now
    //         };
    //         db.Add(m);
    //     }

    //     try
    //     {
    //         await db.SaveChangesAsync(ct);
    //     }
    //     catch (DbUpdateException ex) when (Text.IsUniqueViolation(ex))
    //     {
    //         throw new ConflictDomainException("This person is already a member.");
    //     }

    //     return new MemberDto(m.Id, target.Id, $"{target.FirstName} {target.LastName}", target.Email ?? "",
    //         m.Role, false, true, m.CreatedAtUtc);
    // }

    public async Task ChangeMemberRoleAsync(Guid userId, int businessId, int membershipId, ChangeMemberRoleDto dto, CancellationToken ct)
    {
        var actor = await access.RequireAsync(userId, businessId, true, ct);
        if (!actor.IsPrimaryOwner) throw new ForbiddenDomainException("Only primary owners can change roles.");
        if (!Enum.IsDefined(dto.Role)) throw new ValidationDomainException("Invalid role.");

        // Filtering by BusinessId too: a membership id from another business must not resolve.
        var target = await db.Set<BusinessMembership>()
            .FirstOrDefaultAsync(x => x.Id == membershipId && x.BusinessId == businessId && x.IsActive, ct)
            ?? throw new NotFoundDomainException("Member");

        // The primary owner can never be touched, so a business always keeps one active owner.
        if (target.IsPrimaryOwner) throw new ForbiddenDomainException("The primary owner's role cannot be changed.");

        target.Role = dto.Role;
        await db.SaveChangesAsync(ct);
    }

    public async Task RemoveMemberAsync(Guid userId, int businessId, int membershipId, CancellationToken ct)
    {
        var actor = await access.RequireAsync(userId, businessId, false, ct);

        var target = await db.Set<BusinessMembership>()
            .FirstOrDefaultAsync(x => x.Id == membershipId && x.BusinessId == businessId && x.IsActive, ct)
            ?? throw new NotFoundDomainException("Member");

        if (target.IsPrimaryOwner)
            throw new ForbiddenDomainException("The primary owner cannot be removed. Delete the business instead.");

        var isSelf = target.UserId == userId; // anyone may leave
        if (!isSelf && !actor.IsPrimaryOwner && !Perms.CanManage(actor.Role, target.Role)) throw new ForbiddenDomainException();

        target.IsActive = false; // deactivate, never delete: contacts and history reference this user
        await db.SaveChangesAsync(ct);
    }
}