using System.ComponentModel.DataAnnotations;

namespace MiniCrm.Core.Options;

public sealed class JwtOptions
{
    public const string SectionName = "Jwt";

    [Required(ErrorMessage = "Jwt:Key is required.")]
    [MinLength(32, ErrorMessage = "Jwt:Key must be at least 32 characters for HS256 security.")]
    public string Key { get; set; } = string.Empty;

    [Required(ErrorMessage = "Jwt:Issuer is required.")]
    public string Issuer { get; set; } = "MiniCrm";

    [Required(ErrorMessage = "Jwt:Audience is required.")]
    public string Audience { get; set; } = "MiniCrmClient";

    [Range(1, 1440, ErrorMessage = "AccessTokenExpirationMinutes must be between 1 and 1440.")]
    public int AccessTokenExpirationMinutes { get; set; } = 60;

    [Range(1, 30, ErrorMessage = "RefreshTokenExpirationDays must be between 1 and 30.")]
    public int RefreshTokenExpirationDays { get; set; } = 7;
}