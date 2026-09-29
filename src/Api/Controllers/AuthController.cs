using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using MiniCrm.Application.DTO;
using MiniCrm.Application.Services;
using MiniCrm.Core.Constants;
using MiniCrm.Core.Exceptions;
namespace MiniCrm.Api.Controllers;

[Route("api/[controller]")]
[ApiController]

public class AuthController(IAuthService authService) : ControllerBase
{
    private readonly IAuthService _authService = authService;

    [HttpPost("register/client")]
    [AllowAnonymous]
    public async Task<ActionResult<RegisterResponseDto>> RegisterClient([FromBody] RegisterUserRequest request)
    {
        try
        {
            var result = await _authService.RegisterUserAsync(request);
            return result.ErrorCode switch
            {
                200 => Ok(result.Data),
                409 => Problem(statusCode: StatusCodes.Status409Conflict,
                    title: "Duplicate email",
                    detail: "An account with this email already exists."),
                _ => Problem(statusCode: StatusCodes.Status500InternalServerError,
                    title: "Registration failed"),
            };
        }
        catch (IdentityException ex)
        {
            return Problem(statusCode: StatusCodes.Status500InternalServerError, detail: ex.Message);
        }
    }


    [HttpPost("register/business")]
    [AllowAnonymous]
    public async Task<ActionResult<RegisterResponseDto>> RegisterBusiness([FromBody] RegisterBusinessRequest request)
    {
        try
        {
            var result = await _authService.RegisterBusinessAsync(request);
            return result.ErrorCode switch
            {
                200 => Ok(result.Data),
                409 => Problem(statusCode: StatusCodes.Status409Conflict,
                    title: "Duplicate email",
                    detail: "An account with this email already exists."),
                _ => Problem(statusCode: StatusCodes.Status500InternalServerError,
                    title: "Registration failed"),
            };
        }
        catch (IdentityException ex)
        {
            return Problem(statusCode: StatusCodes.Status500InternalServerError, detail: ex.Message);
        }
    }
    // 401,400,402,403
    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponse>> Login([FromBody] LoginRequest request)
    {
        try
        {
            var result = await _authService.LoginAsync(request);
            return result.ErrorCode switch
            {
                200 => Ok(result.Auth),
                401 => Problem(statusCode: StatusCodes.Status403Forbidden,
                    title: "Account deactivated",
                    detail: "Your account has been deactivated. Contact support.",
                    extensions: new Dictionary<string, object?> { ["code"] = "account-deactivated" }
                    ),
                403 => Problem(statusCode: StatusCodes.Status423Locked,
                    title: "Account locked",
                    detail: "Your account is locked. Try again later.",
                    extensions: new Dictionary<string, object?> { ["code"] = "account-locked" }
                    ),
                402 or 404 => Problem(statusCode: StatusCodes.Status401Unauthorized,
                    title: "Invalid credentials",
                    detail: "Invalid email or password.",
                    extensions: new Dictionary<string, object?> { ["code"] = "invalid-credentials" }
                ),
                405 => Problem(statusCode: StatusCodes.Status403Forbidden,
                    title: "Email not confirmed",
                    detail: "Your need to confirm your email to access your account.",
                    extensions: new Dictionary<string, object?> { ["code"] = "email-not-confirmed" }
                    ),
                _ => Problem(statusCode: StatusCodes.Status500InternalServerError,
                    title: "Login failed"),
            };
        }
        catch (IdentityException ex)
        {
            return Problem(statusCode: StatusCodes.Status500InternalServerError, detail: ex.Message);
        }
    }
    [HttpPost("refresh")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponse>> RefreshToken([FromBody] RefreshTokenRequest request, CancellationToken ct)
    {
        try
        {
            var result = await _authService.RefreshAsync(request, ct);
            return result is null
                ? Problem(statusCode: StatusCodes.Status401Unauthorized,
                    title: "Invalid refresh token", detail: "Session expired. Please log in again.")
                : Ok(result);
        }
        catch (IdentityException ex)
        {
            return Problem(statusCode: StatusCodes.Status500InternalServerError, detail: ex.Message);
        }
    }
    //TODO: /api/auth/me
    [HttpGet("me")]
    [Authorize]
    public async Task<ActionResult<UserDto>> Me()
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
        if (!Guid.TryParse(idClaim, out var userId))
            return Problem(statusCode: StatusCodes.Status401Unauthorized, title: "Invalid token");

        try
        {
            return Ok(await _authService.GetCurrentUserAsync(userId));
        }
        catch (IdentityException)
        {
            return Problem(statusCode: StatusCodes.Status401Unauthorized,
                title: "Unauthorized", detail: "User not found or inactive.");
        }
    }

    [HttpPost("logout")]
    [AllowAnonymous]
    public async Task<IActionResult> Logout([FromBody] RefreshTokenRequest request, CancellationToken ct)
    {
        await _authService.LogoutAsync(request, ct);
        return NoContent();
    }

    [HttpPost("login/google")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponse>> GoogleLogin([FromBody] GoogleLoginRequest request)
    {

        try
        {
            return Ok(await _authService.GoogleLoginAsync(request));
        }
        catch (GoogleBusinessNameRequiredException)
        {
            return Problem(
                statusCode: StatusCodes.Status422UnprocessableEntity,
                title: "Business name required",
                detail: "Please provide your company name to finish creating your account.",
                extensions: new Dictionary<string, object?> { ["code"] = "business-name-required" });
        }
        catch (IdentityException ex)
        {
            return Problem(statusCode: StatusCodes.Status401Unauthorized, detail: ex.Message);
        }
    }
}

