using System.ComponentModel.DataAnnotations;
using MiniCrm.Core.Enums;
using MiniCrm.Infrastructure.Persistence.Entities;

namespace MiniCrm.Application.DTO;


public sealed record CreateInvitationDto(
    string Email,
    BusinessMemberRole Role
);

// No link here on purpose: the link only ever travels by email.
public sealed record InvitationCreatedDto(
    int Id,
    string Email,
    BusinessMemberRole Role,
    DateTime ExpiresAtUtc,
    bool EmailSent);

public sealed record InvitationListItemDto(
    int Id,
    string Email,
    BusinessMemberRole Role,
    InvitationStatus Status,
    DateTime CreatedAtUtc,
    DateTime ExpiresAtUtc,
    string InvitedByName);

// Returned to whoever holds the token (anonymous). Email is masked.
public sealed record InvitationPreviewDto(
    string BusinessName,
    string InviterName,
    BusinessMemberRole Role,
    string EmailHint,
    InvitationStatus Status,
    InviteeAccountState AccountState,
    DateTime ExpiresAtUtc);

public sealed record AcceptInvitationResult(
    int BusinessId,
    string BusinessName,
    BusinessMemberRole Role, 
    bool AlreadyMember);

public sealed record InvitationTokenRequest
{
    [Required, MaxLength(100)]
    public string Token { get; init; } = string.Empty;
}

// No Email field: the address comes from the invitation and cannot be chosen by the caller.
public sealed record RegisterStaffRequest
{
    [Required, MaxLength(100)]
    public string Token { get; init; } = string.Empty;

    [Required, MinLength(8)]
    public string Password { get; init; } = string.Empty;

    [Required, Compare(nameof(Password))]
    public string ConfirmPassword { get; init; } = string.Empty;

    [Required, MaxLength(100)]
    public string FirstName { get; init; } = string.Empty;

    [Required, MaxLength(100)]
    public string LastName { get; init; } = string.Empty;
}