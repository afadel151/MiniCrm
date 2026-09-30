using Google.Apis.Auth;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Configuration;
using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Application.Services;

public interface IGoogleAuthService
{
    Task<GoogleJsonWebSignature.Payload?> ValidateAsync(string idToken);
}

public class GoogleAuthService(UserManager<ApplicationUser> userManager, IConfiguration configuration) : IGoogleAuthService
{
    private readonly UserManager<ApplicationUser> _userManager = userManager;
    private readonly IConfiguration _configuration = configuration;

    
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