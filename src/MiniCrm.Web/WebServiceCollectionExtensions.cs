using System.Globalization;
using Microsoft.AspNetCore.Components.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Localization;
using MiniCrm.Infrastructure.Identity;
using MiniCrm.Web.Components.Account;
using Radzen;

namespace MiniCrm.Web;

public static class WebServiceCollectionExtensions
{
    public static IServiceCollection AddWebServices(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddRadzenComponents();
        services.AddLocalization();
        services.AddHealthChecks();
        services.Configure<RequestLocalizationOptions>(options =>
        {
            var defaultCulture = new CultureInfo("fr-DZ");
            CultureInfo[] supportedCultures = [defaultCulture, new CultureInfo("fr-FR"), new CultureInfo("fr")];
            options.DefaultRequestCulture = new RequestCulture(defaultCulture);
            options.SupportedCultures = supportedCultures;
            options.SupportedUICultures = supportedCultures;
        });
        services.AddCascadingAuthenticationState();
        services.AddScoped<IdentityRedirectManager>();
        services.AddSingleton<IEmailSender<ApplicationUser>, IdentityNoOpEmailSender>();
        services.AddScoped<AuthenticationStateProvider, IdentityRevalidatingAuthenticationStateProvider>();
        return services;
    }
}
