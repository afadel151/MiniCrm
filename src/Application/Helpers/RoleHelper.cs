using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;
using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Application.Helpers;



public interface IRoleHelper
{
    Task<IdentityResult> SetRoleAsync(ApplicationUser user, string role);
    Task<bool> EnsureRoleExistsAsync(string roleName);
}


public class RoleHelper(UserManager<ApplicationUser> userManager,
    RoleManager<ApplicationRole> roleManager,
     ILogger<RoleHelper> logger) : IRoleHelper
{
    private readonly UserManager<ApplicationUser> _userManager = userManager;
    private readonly RoleManager<ApplicationRole> _roleManager = roleManager;
    private readonly ILogger<RoleHelper> _logger = logger;

    public async Task<IdentityResult> SetRoleAsync(
    ApplicationUser user,
    string role)
    {
        if (!await _roleManager.RoleExistsAsync(role))
            return IdentityResult.Failed(
                new IdentityError
                {
                    Description = $"Role '{role}' does not exist."
                });

        var currentRoles = await _userManager.GetRolesAsync(user);

        if (currentRoles.Count > 0)
        {
            var removeResult =
                await _userManager.RemoveFromRolesAsync(user, currentRoles);

            if (!removeResult.Succeeded)
                return removeResult;
        }

        return await _userManager.AddToRoleAsync(user, role);
    }

    public async Task<bool> EnsureRoleExistsAsync(string roleName)
    {
        var roleExists = await _roleManager.RoleExistsAsync(roleName);
        if (!roleExists)
        {
            var roleResult = await _roleManager.CreateAsync(new ApplicationRole(roleName));
            if (!roleResult.Succeeded)
            {
                var errors = string.Join("; ", roleResult.Errors.Select(e => e.Description));
                _logger.LogError("Failed to create role {RoleName}: {Errors}", roleName, errors);
                return false;
            }

            _logger.LogInformation("Role created: {RoleName}", roleName);
            return true;
        }
        return true;
    }
}

/*

*/