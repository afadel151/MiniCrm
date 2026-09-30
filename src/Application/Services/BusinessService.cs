using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.EntityFrameworkCore;
using MiniCrm.Infrastructure.Persistence.Entities;
using MiniCrm.Core.Services;
using MiniCrm.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using MiniCrm.Infrastructure.Identity;
using MiniCrm.Core.Exceptions;
using MiniCrm.Application.Repositories;
using MiniCrm.Application.DTO;

namespace MiniCrm.Application.Services;

public interface IBusinessService
{
    Task<BusinessInfosResult> GetBusinessInfos(Guid userId);
}
public sealed class BusinessService(IBaseRepository<BusinessMembership> businessMembershipRepository, UserManager<ApplicationUser> userManager) : IBusinessService
{
    private readonly UserManager<ApplicationUser> _userManager = userManager;
    private readonly IBaseRepository<BusinessMembership> _businessMembershipRepository = businessMembershipRepository;

    public async Task<BusinessInfosResult> GetBusinessInfos(Guid userId)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString());

        if (user is null || !user.IsActive)
        {
            throw new ForbiddenException("User not found or inactive.");
        }

        try
        {
            var memberships = await _businessMembershipRepository
            .Query()
            .Where(m => m.UserId == user.Id)
            .Include(m => m.Business)
            .ThenInclude(b => b.Memberships)
            .ToListAsync();

            var infos = memberships
                .Where(m => m.Business is not null)
                .Select(m => new BusinessInfo(
                    m.Business!.Id,
                    m.Business.Name,
                    m.Business.IsActive,
                    m.Business.Memberships.Count,
                    new MembershipInfo(
                        m.Id,
                        m.Role,
                        m.IsActive
                    )
                ))
                .ToList();

            return new BusinessInfosResult(infos);
        }
        catch (Exception ex)
        {
            Console.WriteLine("######### " + ex);
            throw new DatabaseException();

        }
    }
}