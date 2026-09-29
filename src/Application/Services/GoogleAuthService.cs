using Google.Apis.Auth;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Configuration;
using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Application.Services;

public interface IGoogleAuthService
{
    Task<ApplicationUser?> ValidateAndGetUserAsync(string googleIdToken);
    Task<GoogleJsonWebSignature.Payload?> ValidateAsync(string idToken);
}

public class GoogleAuthService(UserManager<ApplicationUser> userManager, IConfiguration configuration) : IGoogleAuthService
{
    private readonly UserManager<ApplicationUser> _userManager = userManager;
    private readonly IConfiguration _configuration = configuration;

    public async Task<ApplicationUser?> ValidateAndGetUserAsync(string googleIdToken)
    {
        var googleClientId = _configuration["Authentication:Google:ClientId"];

        if (string.IsNullOrEmpty(googleClientId))
            throw new InvalidOperationException("Google Client ID is not configured in appsettings.");

        var settings = new GoogleJsonWebSignature.ValidationSettings { Audience = [googleClientId] };

        GoogleJsonWebSignature.Payload payload;
        try
        {
            payload = await GoogleJsonWebSignature.ValidateAsync(googleIdToken, settings);
        }
        catch
        {
            return null; // Invalid signature or expired
        }

        var user = await _userManager.FindByEmailAsync(payload.Email);
        if (user == null)
        {
            user = new ApplicationUser
            {
                UserName = payload.Email,
                Email = payload.Email,
                FirstName = payload.GivenName ?? string.Empty,
                LastName = payload.FamilyName ?? string.Empty,
                EmailConfirmed = true,
                IsActive = true,
                CreatedAtUtc = DateTime.UtcNow
            };

            var result = await _userManager.CreateAsync(user);
            if (!result.Succeeded) return null;

            await _userManager.AddToRoleAsync(user, AppRoles.Client);
        }

        var logins = await _userManager.GetLoginsAsync(user);
        if (!logins.Any(l => l.LoginProvider == "Google" && l.ProviderKey == payload.Subject))
        {
            await _userManager.AddLoginAsync(user, new UserLoginInfo("Google", payload.Subject, "Google"));
        }

        return user;
    }
    public async Task<GoogleJsonWebSignature.Payload?> ValidateAsync(string idToken)
    {
        var clientId = _configuration["Authentication:Google:ClientId"]
            ?? throw new InvalidOperationException("Google Client ID is not configured.");

        try
        {
            return await GoogleJsonWebSignature.ValidateAsync(idToken,
                new GoogleJsonWebSignature.ValidationSettings { Audience = [clientId] });
        }
        catch
        {
            return null; // bad signature / expired / wrong audience
        }
    }
}