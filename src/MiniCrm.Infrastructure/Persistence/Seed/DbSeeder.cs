using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using MiniCrm.Infrastructure.Identity;
using MiniCrm.Infrastructure.Persistence.Entities;

namespace MiniCrm.Infrastructure.Persistence.Seed;

public static class DbSeeder
{
    public static async Task SeedAsync(IServiceProvider services, CancellationToken ct = default)
    {
        using IServiceScope scope = services.CreateScope();
        IServiceProvider sp = scope.ServiceProvider;

        AppDbContext db     = sp.GetRequiredService<AppDbContext>();
        RoleManager<ApplicationRole> roles  = sp.GetRequiredService<RoleManager<ApplicationRole>>();
        UserManager<ApplicationUser> users  = sp.GetRequiredService<UserManager<ApplicationUser>>();
        IConfiguration config = sp.GetRequiredService<IConfiguration>();
        ILogger log    = sp.GetRequiredService<ILoggerFactory>().CreateLogger(nameof(DbSeeder));

        await SeedRolesAsync(roles);
        await SeedStagesAsync(db, ct);
        await SeedAdminAsync(users, config, log);
    }

    private static async Task SeedRolesAsync(RoleManager<ApplicationRole> roles)
    {
        foreach (string? name in AppRoles.All)
        {
            if (await roles.RoleExistsAsync(name)) continue;
            IdentityResult result = await roles.CreateAsync(new ApplicationRole(name));
            if (!result.Succeeded)
                throw new InvalidOperationException($"Creating role '{name}' failed: {Describe(result)}");
        }
    }

    private static async Task SeedStagesAsync(AppDbContext db, CancellationToken ct)
    {
        PipelineStage[] stages =
        [
            new PipelineStage { Name = "Prospect",    SortOrder = 10,  DefaultProbability = 10,  IsWon = false, IsLost = false, IsActive = true },
            new PipelineStage { Name = "Qualifié",    SortOrder = 20,  DefaultProbability = 30,  IsWon = false, IsLost = false, IsActive = true },
            new PipelineStage { Name = "Proposition", SortOrder = 30,  DefaultProbability = 50,  IsWon = false, IsLost = false, IsActive = true },
            new PipelineStage { Name = "Négociation", SortOrder = 40,  DefaultProbability = 70,  IsWon = false, IsLost = false, IsActive = true },
            new PipelineStage { Name = "Gagné",       SortOrder = 90,  DefaultProbability = 100, IsWon = true,  IsLost = false, IsActive = true },
            new PipelineStage { Name = "Perdu",       SortOrder = 100, DefaultProbability = 0,   IsWon = false, IsLost = true,  IsActive = true },
        ];

        foreach (PipelineStage? stage in stages)
        {
            if (await db.PipelineStages.AnyAsync(s => s.Name == stage.Name, ct)) continue;
            db.PipelineStages.Add(stage);
        }
        await db.SaveChangesAsync(ct);
    }

    private static async Task SeedAdminAsync(UserManager<ApplicationUser> users, IConfiguration config, ILogger log)
    {
        string? email = config["Seed:AdminEmail"];
        string? password = config["Seed:AdminPassword"];

        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
        {
            log.LogWarning("Seed:AdminEmail / Seed:AdminPassword not set; skipping admin creation.");
            return;
        }

        if (await users.FindByEmailAsync(email) is not null) return;

        var admin = new ApplicationUser
        {
            UserName = email,
            Email = email,
            EmailConfirmed = true,     
            FirstName = "System",
            LastName = "Admin",
            IsActive = true,
            MustChangePassword = true,
            CreatedAtUtc = DateTime.UtcNow
        };

        IdentityResult create = await users.CreateAsync(admin, password);
        if (!create.Succeeded)
            throw new InvalidOperationException($"Creating admin failed: {Describe(create)}");

        IdentityResult addRole = await users.AddToRoleAsync(admin, AppRoles.Admin);
        if (!addRole.Succeeded)
        {
            await users.DeleteAsync(admin); 
            throw new InvalidOperationException($"Assigning Admin role failed: {Describe(addRole)}");
        }

        log.LogInformation("Seeded admin user {Email}", email);
    }

    private static string Describe(IdentityResult r) => string.Join("; ", r.Errors.Select(e => e.Description));
}