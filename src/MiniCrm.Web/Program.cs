using System.Globalization;
using Microsoft.AspNetCore.Authorization;
using MiniCrm.Core;
using MiniCrm.Infrastructure;
using MiniCrm.Infrastructure.Identity;
using MiniCrm.Infrastructure.Persistence.Seed;
using MiniCrm.Web;
using MiniCrm.Web.Components;
using MiniCrm.Web.Components.Account;
using Serilog;

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((context, services, configuration) => configuration
    .ReadFrom.Configuration(context.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console(formatProvider: CultureInfo.InvariantCulture)
    .WriteTo.File("logs/minicrm-.log", rollingInterval: RollingInterval.Day, formatProvider: CultureInfo.InvariantCulture));

// Service registrations
builder.Services
    .AddCore()
    .AddInfrastructure(builder.Configuration)
    .AddWebServices(builder.Configuration);

builder.Services.AddAuthorizationBuilder()
    .AddPolicy(AppPolicies.AdminOnly, p => p.RequireRole(AppRoles.Admin))
    .AddPolicy(AppPolicies.StaffOnly, p => p.RequireRole(AppRoles.Staff))
    .SetFallbackPolicy(new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        // .RequireRole(AppRoles.Staff)
        .Build());

builder.Services.ConfigureApplicationCookie(o =>
{
    o.LoginPath = "/Account/Login";
    o.AccessDeniedPath = "/Account/AccessDenied";
});


builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents(options => options.DetailedErrors = builder.Environment.IsDevelopment());

WebApplication app = builder.Build();
await DbSeeder.SeedAsync(app.Services);
// Middleware pipeline
if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}
else
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseRequestLocalization();
app.UseStaticFiles();
app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();
app.UseAntiforgery();

app.MapHealthChecks("/healthz");
app.MapAdditionalIdentityEndpoints();

app.MapStaticAssets().AllowAnonymous(); 
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
