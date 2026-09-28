
using System.ComponentModel;
using System.Security.Principal;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;
using MiniCrm.Application.DTO;
using MiniCrm.Core.Exceptions;
using MiniCrm.Core.Services;
using MiniCrm.Infrastructure.Identity;
using MiniCrm.Infrastructure.Persistence;

namespace MiniCrm.Application.Services;


public interface IAuthService
{
    Task<RegisterResponse> RegisterUserAsync(RegisterUserRequest request);
    Task<RegisterResponse> RegisterBusinessAsync(RegisterBusinessRequest request);
    Task<LoginResponse> LoginAsync(LoginRequest request);
    Task<AuthResponse> GoogleLoginAsync(GoogleLoginRequest request);
    Task<UserDto> GetCurrentUserAsync(Guid userId);
    Task<AuthResponse?> RefreshAsync(RefreshTokenRequest request, CancellationToken ct = default);
    Task LogoutAsync(RefreshTokenRequest request, CancellationToken ct = default);
}
public class AuthService(
    UserManager<ApplicationUser> userManager,
    SignInManager<ApplicationUser> signInManager,
    RoleManager<ApplicationRole> roleManager,
    ITokenService tokenService,
    IGoogleAuthService googleAuthService,
    ILogger<AuthService> logger) : IAuthService
{

    private readonly UserManager<ApplicationUser> _userManager = userManager;
    private readonly SignInManager<ApplicationUser> _signInManager = signInManager;
    private readonly RoleManager<ApplicationRole> _roleManager = roleManager;
    private readonly ITokenService _tokenService = tokenService;
    private readonly IGoogleAuthService _googleAuthService = googleAuthService;
    private readonly ILogger<AuthService> _logger = logger;
    public async Task<RegisterResponse> RegisterUserAsync(RegisterUserRequest request)
    {
        var existingUser = await _userManager.FindByEmailAsync(request.Email);
        if (existingUser is not null)
        {
            // TODO: 409 user exists
            // throw new IdentityException("An account with this email already exists.");
            return new RegisterResponse(
                Data: null,
                ErrorCode: 409
            );

        }

        // 2. Ensure the "Client" role exists in the database (RoleManager.RoleExistsAsync)
        var roleCreated = await EnsureRoleExistsAsync(AppRoles.Client);
        if (!roleCreated)
        {
            throw new IdentityException("Error creating Client role");
        }
        // 3. Create the user entity
        var user = new ApplicationUser
        {
            UserName = request.Email,
            Email = request.Email,
            FirstName = request.FirstName.Trim(),
            LastName = request.LastName.Trim(),
            IsActive = true,
            MustChangePassword = false,
            CreatedAtUtc = DateTime.UtcNow
        };

        // 4. Create user with password (UserManager.CreateAsync)
        // var ValidPassword = await _userManager.PasswordV
        var result = await _userManager.CreateAsync(user, request.Password);
        if (!result.Succeeded)
        {
            var errors = string.Join("; ", result.Errors.Select(e => e.Description));
            _logger.LogWarning("User registration failed for {Email}: {Errors}", request.Email, errors);
            //TODO: 500  failed registration
            throw new IdentityException("failed user registration");

        }

        // 5. Assign role (UserManager.AddToRoleAsync)
        var roleResult = await _userManager.AddToRoleAsync(user, AppRoles.Client);
        if (!roleResult.Succeeded)
        {
            _logger.LogError("Failed to assign Client role to user {UserId}", user.Id);
            //TODO: 500 failed to assign role
            throw new IdentityException("Failed to assign Client role to user");

        }

        _logger.LogInformation("New Client registered: {Email} ({UserId})", user.Email, user.Id);
        //TODO: 200 success
        return new RegisterResponse(
            Data: new RegisterResponseDto(
                Email: user.Email!
            ),
            ErrorCode: 200
        );
    }

    public async Task<RegisterResponse> RegisterBusinessAsync(RegisterBusinessRequest request)
    {
        // 1. Check if email already exists
        var existingUser = await _userManager.FindByEmailAsync(request.Email);
        if (existingUser is not null)
        {
            throw new IdentityException("An account with this email already exists.");
        }

        // 2. Ensure the "BusinessManager" role exists
        await EnsureRoleExistsAsync(AppRoles.BusinessManager);

        // 3. Create the user entity
        var user = new ApplicationUser
        {
            UserName = request.Email,
            Email = request.Email,
            FirstName = request.FirstName.Trim(),
            LastName = request.LastName.Trim(),
            PhoneNumber = request.PhoneNumber,
            IsActive = true,
            MustChangePassword = true, // Force password change on first login for business accounts
            CreatedAtUtc = DateTime.UtcNow
        };

        // 4. Create user with password (UserManager.CreateAsync)
        var result = await _userManager.CreateAsync(user, request.Password);
        if (!result.Succeeded)
        {
            var errors = string.Join("; ", result.Errors.Select(e => e.Description));
            _logger.LogWarning("Business registration failed for {Email}: {Errors}", request.Email, errors);
            throw new IdentityException($"Registration failed: {errors}");
        }

        // 5. Assign BusinessManager role (UserManager.AddToRoleAsync)
        var roleResult = await _userManager.AddToRoleAsync(user, AppRoles.BusinessManager);
        if (!roleResult.Succeeded)
        {
            _logger.LogError("Failed to assign BusinessManager role to user {UserId}", user.Id);
            throw new IdentityException("Failed to assign business role.");
        }

        // TODO: Create the Business/Tenant entity in your database here
        // e.g., await _businessRepository.CreateAsync(new Business { Name = request.BusinessName, OwnerId = user.Id });

        _logger.LogInformation(
            "New Business registered: {BusinessName} by {Email} ({UserId})",
            request.BusinessName, user.Email, user.Id
        );

        return new RegisterResponse(
            ErrorCode: 200,
            Data: new RegisterResponseDto(
                Email: user.Email!
            )
        );
    }

    public async Task<LoginResponse> LoginAsync(LoginRequest request)
    {
        var user = await _userManager.FindByEmailAsync(request.Email);
        if (user is null)
            return new LoginResponse(ErrorCode: 404, Auth: null);

        if (await _userManager.IsLockedOutAsync(user))
            return new LoginResponse(ErrorCode: 403, Auth: null);

        if (!await _userManager.CheckPasswordAsync(user, request.Password))
        {
            await _userManager.AccessFailedAsync(user);
            _logger.LogWarning("Failed login attempt for {Email}", request.Email);

            return await _userManager.IsLockedOutAsync(user)
                ? new LoginResponse(ErrorCode: 403, Auth: null)
                : new LoginResponse(ErrorCode: 402, Auth: null);
        }

        // Only after a correct password do we reveal the account state.
        if (!user.IsActive)
            return new LoginResponse(ErrorCode: 401, Auth: null);

        // 4. Reset failed access count on successful login (UserManager.ResetAccessFailedCountAsync)
        try
        {

            await _userManager.ResetAccessFailedCountAsync(user);
            _logger.LogInformation("Failed access count reset");

            // 5. Update last login timestamp
            user.LastLoginAtUtc = DateTime.UtcNow;
            await _userManager.UpdateAsync(user);
            _logger.LogInformation("User updated");

            // 6. Generate JWT token
            var token = await _tokenService.GenerateTokenAsync(user, Refresh: true); ;
            _logger.LogInformation("User logged in: {Email} ({UserId})", user.Email, user.Id);
            return new LoginResponse(
                ErrorCode: 200,
                Auth: token
            );
        }
        catch (Exception ex)
        {
            throw new IdentityException("Error logging user ", ex);
        }
    }
    public async Task<AuthResponse> GoogleLoginAsync(GoogleLoginRequest request)
    {
        // 1. Validate Google ID Token and find/create user
        var user = await _googleAuthService.ValidateAndGetUserAsync(request.IdToken) ?? throw new IdentityException("Google authentication failed. Invalid token.");

        // 2. Check if account is active
        if (!user.IsActive)
        {
            throw new IdentityException("Your account has been deactivated. Contact support.");
        }

        // 3. Update last login
        user.LastLoginAtUtc = DateTime.UtcNow;
        await _userManager.UpdateAsync(user);

        // 4. Generate JWT token
        var token = await _tokenService.GenerateTokenAsync(user, Refresh: true);

        _logger.LogInformation("Google login: {Email} ({UserId})", user.Email, user.Id);

        return token;
    }

    public async Task<UserDto> GetCurrentUserAsync(Guid userId)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString());
        if (user is null || !user.IsActive)
        {
            throw new IdentityException("User not found or inactive.");
        }

        // Get roles (UserManager.GetRolesAsync)
        var roles = await _userManager.GetRolesAsync(user);

        return new UserDto(
            Id: user.Id,
            Email: user.Email!,
            FirstName: user.FirstName,
            LastName: user.LastName,
            Roles: [.. roles],
            MustChangePassword: user.MustChangePassword
        );
    }
    private async Task<bool> EnsureRoleExistsAsync(string roleName)
    {
        // RoleManager.RoleExistsAsync - checks if the role is in the database
        var roleExists = await _roleManager.RoleExistsAsync(roleName);
        if (!roleExists)
        {
            // RoleManager.CreateAsync - creates the role if missing
            var roleResult = await _roleManager.CreateAsync(new ApplicationRole(roleName));
            if (!roleResult.Succeeded)
            {
                var errors = string.Join("; ", roleResult.Errors.Select(e => e.Description));
                _logger.LogError("Failed to create role {RoleName}: {Errors}", roleName, errors);
                return false;
            }

            _logger.LogInformation("Role created: {RoleName}", roleName);
            return true;
        }
        return true;
    }
    public Task<AuthResponse?> RefreshAsync(RefreshTokenRequest request, CancellationToken ct = default)
        => _tokenService.RefreshAsync(request.RefreshToken, ct);

    public Task LogoutAsync(RefreshTokenRequest request, CancellationToken ct = default)
        => _tokenService.RevokeAsync(request.RefreshToken, ct);

}
