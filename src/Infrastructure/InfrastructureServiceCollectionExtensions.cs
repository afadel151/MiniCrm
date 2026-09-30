// MiniCrm.Infrastructure/InfrastructureServiceCollectionExtensions.cs
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using MiniCrm.Core.Options;
using MiniCrm.Infrastructure.Identity;
using MiniCrm.Infrastructure.Persistence;

namespace MiniCrm.Infrastructure;

public static class InfrastructureServiceCollectionExtensions
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        // 1. General Services
        services.AddSingleton(TimeProvider.System);
        // services.AddSingleton<ILocalTime, LocalTime>(); // Keep if you have it
        services.AddHttpContextAccessor();

        // 2. Database
        string connectionString = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("ConnectionStrings:Default is missing.");

        services.AddDbContext<AppDbContext>(options =>
            options.UseSqlServer(connectionString, sql =>
            {
                // Dynamically gets "MiniCrm.Infrastructure" (or whatever your project is named)
                // This prevents hardcoded string errors when running EF migrations.
                sql.MigrationsAssembly(typeof(AppDbContext).Assembly.GetName().Name);

                // Optional: Good practice for Azure SQL / unstable networks
                sql.EnableRetryOnFailure(maxRetryCount: 3);
            })
        );

        services.AddScoped<IDbContextFactory<AppDbContext>,AppDbContextFactory>();

        // 3. Identity (Core setup, NO COOKIES)
        services.AddIdentityCore<ApplicationUser>(options =>
        {
            options.Password.RequiredLength = 8;
            options.Password.RequireDigit = true;
            options.Password.RequireLowercase = true;
            options.Password.RequireNonAlphanumeric = true;
            options.Password.RequireUppercase = true;
            options.User.RequireUniqueEmail = true;
        })
        .AddRoles<ApplicationRole>()
        .AddEntityFrameworkStores<AppDbContext>()
        .AddSignInManager()
        .AddDefaultTokenProviders();

        // 4. Authentication (JWT Bearer for API)
        // REMOVED: AddIdentityCookies() and AddGoogle()
        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = configuration[$"{JwtOptions.SectionName}:Issuer"],

                    ValidateAudience = true,
                    ValidAudience = configuration[$"{JwtOptions.SectionName}:Audience"],

                    ValidateLifetime = true,
                    ClockSkew = TimeSpan.Zero,

                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(
                        Encoding.UTF8.GetBytes(configuration[$"{JwtOptions.SectionName}:Key"]!)
                    ),

                    RoleClaimType = "role",
                    NameClaimType = System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Sub
                };
            });

        // 5. Authorization Policies
        services.AddAuthorizationBuilder()
            .AddPolicy(AppPolicies.AdminOnly, policy => policy.RequireRole(AppRoles.Admin))
            .AddPolicy(AppPolicies.BusinessOnly, policy => policy.RequireRole(AppRoles.Admin, AppRoles.Business))
            .AddPolicy(AppPolicies.ClientOnly, policy => policy.RequireRole(AppRoles.Client));

        // 6. Application Services (Implementations)

        return services;
    }
}