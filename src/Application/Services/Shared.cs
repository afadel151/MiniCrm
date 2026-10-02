using System.Net.Mail;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using MiniCrm.Core.Enums;
using MiniCrm.Core.Exceptions;
using MiniCrm.Infrastructure.Persistence;
using MiniCrm.Infrastructure.Persistence.Entities;

namespace MiniCrm.Application.Services;


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
