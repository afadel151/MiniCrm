using Microsoft.Extensions.DependencyInjection;
using MiniCrm.Application.Helpers;
using MiniCrm.Application.Repositories;
using MiniCrm.Application.Services;
using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Application;

public static class ApplicationServiceCollectionExtensions
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<ITokenService, TokenService>();
        services.AddScoped<IGoogleAuthService, GoogleAuthService>();
        services.AddScoped<IAuditService, AuditService>();
        services.AddScoped<IBusinessService, BusinessService>();
        services.AddProblemDetails();
        services.AddExceptionHandler<DomainExceptionHandler>();
        services.AddScoped<BusinessAccess>();
        services.AddScoped<IDirectoryService, DirectoryService>();
        services.AddScoped<IContactService, ContactService>();

        services.AddScoped<IInvitationService, InvitationService>();

        services.AddScoped<IRoleHelper, RoleHelper>();
        services.AddScoped(typeof(IBaseRepository<>), typeof(BaseRepository<>));
        return services;
    }
}