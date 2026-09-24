using System.ComponentModel.DataAnnotations;

namespace MiniCrm.Core.Options;

public sealed class JwtOptions
{
    public const string SectionName = "Jwt";

    [MinLength(32, ErrorMessage = "Jwt:Key doit contenir au moins 32 caractères.")]
    public string Key { get; set; } = string.Empty;

    [Required(ErrorMessage = "Jwt:Issuer est requis.")]
    public string Issuer { get; set; } = "MiniCrm";

    [Required(ErrorMessage = "Jwt:Audience est requis.")]
    public string Audience { get; set; } = "MiniCrmClient";

    [Range(1, 1440)]
    public int AccessTokenExpirationMinutes { get; set; } = 15;

    [Range(1, 30)]
    public int RefreshTokenExpirationDays { get; set; } = 7;
}
