using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using MiniCrm.Core.Services;
using MiniCrm.Infrastructure.Identity;
using MiniCrm.Infrastructure.Persistence;
using MiniCrm.Infrastructure.Services;
using Microsoft.AspNetCore.Authentication.Google;
using Microsoft.AspNetCore.Authentication;
using System.Security.Claims;
namespace MiniCrm.Infrastructure;

public static class InfrastructureServiceCollectionExtensions
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddSingleton(TimeProvider.System);
        services.AddSingleton<ILocalTime, LocalTime>();
        services.AddScoped<IAuditService, AuditService>();

        string connectionString = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("ConnectionStrings:Default is missing.");

        services.AddDbContextFactory<AppDbContext>(options =>
            options.UseSqlServer(connectionString, sql => sql.EnableRetryOnFailure()));

        services.AddScoped(sp => sp.GetRequiredService<IDbContextFactory<AppDbContext>>().CreateDbContext());
        services.AddHttpContextAccessor();

        services.AddIdentityCore<ApplicationUser>(options =>
        {
            options.Password.RequireDigit = true;
            options.Password.RequireLowercase = true;
            options.Password.RequireNonAlphanumeric = true;
            options.Password.RequireUppercase = true;
            options.Password.RequiredLength = 8;
            options.User.RequireUniqueEmail = true;
        })
        .AddRoles<ApplicationRole>()
        .AddEntityFrameworkStores<AppDbContext>()
        .AddSignInManager()
        .AddDefaultTokenProviders();

        AuthenticationBuilder authentication = services.AddAuthentication(options =>
        {
            options.DefaultScheme = IdentityConstants.ApplicationScheme;
            options.DefaultSignInScheme = IdentityConstants.ExternalScheme;
        });

        authentication.AddIdentityCookies();

        authentication.AddGoogle(o =>
        {
            o.ClientId = configuration["Authentication:Google:ClientId"]
                ?? throw new InvalidOperationException("Google ClientId missing.");
            o.ClientSecret = configuration["Authentication:Google:ClientSecret"]
                ?? throw new InvalidOperationException("Google ClientSecret missing.");
            o.Scope.Add("profile");
            o.Scope.Add("email");

            o.ClaimActions.MapJsonKey(
                ClaimTypes.GivenName,
                "given_name");

            o.ClaimActions.MapJsonKey(
                ClaimTypes.Surname,
                "family_name");

            o.ClaimActions.MapJsonKey(
                ClaimTypes.Email,
                "email");
        });
        return services;
    }
}
