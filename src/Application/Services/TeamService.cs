using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.EntityFrameworkCore;
using MiniCrm.Infrastructure.Persistence.Entities;
using MiniCrm.Core.Services;
using MiniCrm.Infrastructure.Persistence;

namespace MiniCrm.Application.Services;

public interface ITeamService
{

}
public sealed class TeamService(IDbContextFactory<AppDbContext> dbFactory) : ITeamService
{
    private readonly IDbContextFactory<AppDbContext> _dbFactory = dbFactory;

    public static async Task InviteStaff()
    {
        return;
    }
}