using System.ComponentModel.DataAnnotations;

namespace MiniCrm.Application.DTO;

public sealed record RegisterUserRequest
{
    [Required, EmailAddress]
    public string Email { get; init; } = string.Empty;

    [Required, MinLength(8)]
    public string Password { get; init; } = string.Empty;

    [Required, Compare(nameof(Password))]
    public string ConfirmPassword { get; init; } = string.Empty;

    [Required, MaxLength(100)]
    public string FirstName { get; init; } = string.Empty;

    [Required, MaxLength(100)]
    public string LastName { get; init; } = string.Empty;
}
/// <summary>
/// Business registration (gets BusinessManager role)
/// </summary>
public sealed record RegisterBusinessRequest
{
    [Required, EmailAddress]
    public string Email { get; init; } = string.Empty;

    [Required, MinLength(8)]
    public string Password { get; init; } = string.Empty;

    [Required, Compare(nameof(Password))]
    public string ConfirmPassword { get; init; } = string.Empty;

    [Required, MaxLength(100)]
    public string FirstName { get; init; } = string.Empty;

    [Required, MaxLength(100)]
    public string LastName { get; init; } = string.Empty;

    [Required, MaxLength(200)]
    public string BusinessName { get; init; } = string.Empty;

}

// ==========================================
// LOGIN DTOs
// ==========================================

public sealed record LoginRequest
{
    [Required, EmailAddress]
    public string Email { get; init; } = string.Empty;

    [Required]
    public string Password { get; init; } = string.Empty;
}

public sealed record GoogleLoginRequest
{
    [Required]
    public string IdToken { get; init; } = string.Empty;
}

// ==========================================
// RESPONSE DTOs
// ==========================================

public sealed record AuthResponse(
    string AccessToken,
    long ExpiresIn,
    string TokenType = "Bearer",
    string? RefreshToken = null
);

public sealed record UserDto(
    Guid Id,
    string Email,
    string FirstName,
    string LastName,
    IList<string> Roles,
    bool MustChangePassword
);
public sealed record RegisterResponse(
    RegisterResponseDto? Data,
    int? ErrorCode = 200
);
public sealed record RegisterResponseDto(
    string Email
);

public sealed record LoginResponse(
    AuthResponse? Auth,
    int? ErrorCode = 200
);


public sealed record RefreshTokenRequest
{
    [Required, MaxLength(512)]
    public string RefreshToken { get; init; } = string.Empty;
}