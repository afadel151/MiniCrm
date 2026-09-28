using Microsoft.Extensions.DependencyInjection;
using MiniCrm.Application.Services;
using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Application;

public static class ApplicationServiceCollectionExtensions
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddScoped<IAuthService,AuthService>();
        services.AddScoped<ITokenService,TokenService>();
        services.AddScoped<IGoogleAuthService,GoogleAuthService>();
        services.AddScoped<IAuditService,AuditService>();

        return services;
    }
}