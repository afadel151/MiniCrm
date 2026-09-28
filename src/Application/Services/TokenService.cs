// MiniCrm.Infrastructure.Identity/ITokenService.cs & TokenService.cs
using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using MiniCrm.Application.DTO;
using MiniCrm.Core.Options;
using MiniCrm.Infrastructure.Identity;
using MiniCrm.Infrastructure.Persistence;
using MiniCrm.Infrastructure.Persistence.Entities;

namespace MiniCrm.Application.Services;

public interface ITokenService
{
    Task<AuthResponse> GenerateTokenAsync(ApplicationUser user, bool Refresh = false);
    Task<string> GenerateRefreshTokenAsync(ApplicationUser user, CancellationToken cancellationToken = default);
    Task<AuthResponse?> RefreshAsync(string rawRefreshToken, CancellationToken cancellationToken = default);
    Task RevokeAsync(string rawRefreshToken, CancellationToken ct = default);
}

public class TokenService(UserManager<ApplicationUser> userManager, IOptions<JwtOptions> jwtOptions, IDbContextFactory<AppDbContext> dbFactory) : ITokenService
{
    private readonly UserManager<ApplicationUser> _userManager = userManager;
    private readonly JwtOptions _jwtOptions = jwtOptions.Value;
    private readonly IDbContextFactory<AppDbContext> _dbFactory = dbFactory;
    private const int RefreshTokenDays = 7;
    private const string ReasonRotated = "Rotated";
    private const string ReasonReuse = "Reuse detected";
    private const string ReasonLogout = "Logout";
    private static readonly TimeSpan RotationGrace = TimeSpan.FromSeconds(10);
    private static string NewRawToken() => Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
    private static string Hash(string raw) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(raw)));

    public async Task<AuthResponse> GenerateTokenAsync(ApplicationUser user, bool Refresh = false)
    {

        var roles = await _userManager.GetRolesAsync(user);

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Email, user.Email ?? string.Empty),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new(JwtRegisteredClaimNames.Iat, DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString(), ClaimValueTypes.Integer64),
            new("given_name", user.FirstName),
            new("family_name", user.LastName),
            new("client_id", "nuxt-web-app"),
            new(AppClaims.MustChangePassword, user.MustChangePassword.ToString().ToLower(CultureInfo.CurrentCulture))
        };

        foreach (var role in roles)
        {
            claims.Add(new Claim("role", role));
        }

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwtOptions.Key));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _jwtOptions.Issuer,
            audience: _jwtOptions.Audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(_jwtOptions.AccessTokenExpirationMinutes),
            signingCredentials: creds
        );
        string? refreshToken = Refresh ? await GenerateRefreshTokenAsync(user) : null;
        return new AuthResponse(
            AccessToken: new JwtSecurityTokenHandler().WriteToken(token),
            RefreshToken: refreshToken,
            ExpiresIn: _jwtOptions.AccessTokenExpirationMinutes * 60
        );
    }
    public async Task<string> GenerateRefreshTokenAsync(ApplicationUser user, CancellationToken cancellationToken = default)
    {
        var rawToken = NewRawToken();

        await using var db = await _dbFactory.CreateDbContextAsync(cancellationToken);
        db.RefreshTokens.Add(new RefreshToken
        {
            TokenHash = Hash(rawToken),
            UserId = user.Id,
            ExpiresAtUtc = DateTime.UtcNow.AddDays(RefreshTokenDays)
        });
        await db.SaveChangesAsync(cancellationToken);

        return rawToken;
    }

    public async Task<AuthResponse?> RefreshAsync(string rawRefreshToken, CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        var hash = Hash(rawRefreshToken);
        await using var db = await _dbFactory.CreateDbContextAsync(cancellationToken);

        var stored = await db.RefreshTokens.AsNoTracking().SingleOrDefaultAsync(t => t.TokenHash == hash, cancellationToken);
        if (stored is null) return null;

        if (stored.RevokedAtUtc is not null)
        {
            if (stored.RevokedReason != ReasonRotated) return null;

            if (now - stored.RevokedAtUtc.Value > RotationGrace)
            {
                // An already-rotated token came back late: treat it as stolen and kill every live token of this user.
                await db.RefreshTokens
                    .Where(t => t.UserId == stored.UserId && t.RevokedAtUtc == null)
                    .ExecuteUpdateAsync(s => s
                        .SetProperty(t => t.RevokedAtUtc, now)
                        .SetProperty(t => t.RevokedReason, ReasonReuse), cancellationToken);
                return null;
            }
            // else: inside the grace window, a parallel request just rotated it. Fall through and issue again.
        }

        if (stored.ExpiresAtUtc <= now) return null;

        var user = await _userManager.FindByIdAsync(stored.UserId.ToString());
        if (user is null || !user.IsActive || await _userManager.IsLockedOutAsync(user)) return null;

        var newRaw = NewRawToken();
        var newHash = Hash(newRaw);

        if (stored.RevokedAtUtc is null)
        {
            // Atomic compare-and-set: only one of two simultaneous requests wins the revoke.
            var won = await db.RefreshTokens
                .Where(t => t.Id == stored.Id && t.RevokedAtUtc == null)
                .ExecuteUpdateAsync(s => s
                    .SetProperty(t => t.RevokedAtUtc, now)
                    .SetProperty(t => t.RevokedReason, ReasonRotated)
                    .SetProperty(t => t.ReplacedByTokenHash, newHash), cancellationToken);

            if (won == 0)
            {
                var reason = await db.RefreshTokens.Where(t => t.Id == stored.Id)
                    .Select(t => t.RevokedReason).SingleAsync(cancellationToken);
                if (reason != ReasonRotated) return null;
            }
        }

        db.RefreshTokens.Add(new RefreshToken
        {
            UserId = user.Id,
            TokenHash = newHash,
            ExpiresAtUtc = now.AddDays(RefreshTokenDays)
        });
        await db.SaveChangesAsync(cancellationToken);

        var access = await GenerateTokenAsync(user); // reloads roles and MustChangePassword
        return access with { RefreshToken = newRaw };
    }

    public async Task RevokeAsync(string rawRefreshToken, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        await using var db = await _dbFactory.CreateDbContextAsync(ct);

        // Follow the rotation chain: the cookie can hold a token that was rotated a moment ago.
        string? hash = Hash(rawRefreshToken);
        for (var i = 0; i < 5 && hash is not null; i++)
        {
            var token = await db.RefreshTokens.SingleOrDefaultAsync(t => t.TokenHash == hash, ct);
            if (token is null) break;

            token.RevokedAtUtc ??= now;
            // Overwriting "Rotated" also closes the grace window, so this token can't be refreshed after logout.
            token.RevokedReason = ReasonLogout;
            hash = token.ReplacedByTokenHash;
        }

        await db.SaveChangesAsync(ct);
    }
}