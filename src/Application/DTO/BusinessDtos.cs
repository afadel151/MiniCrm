

using MiniCrm.Core.Enums;

namespace MiniCrm.Application.DTO;


public sealed record BusinessInfosResult(
    IList<BusinessInfo> Infos
);


public sealed record BusinessInfo(
    int Id,
    string BusinessName,
    bool IsActive,
    int MembershipCount,
    MembershipInfo MembershipInfo
);

public sealed record MembershipInfo(
    int Id,
    BusinessMemberRole Role,
    bool IsActive
    // DateTime JoinedAtUtc
);

public sealed record CreateBusinessDto(
    string BusinessName,
    string Description,
    BusinessDomain BusinessDomain,
    string? BusinessAdress,
    string? Website
);

public sealed record BusinessDetail(
    int Id,
    string BusinessName,
    string? Description,
    string? Website,
    string? BusinessAdress,
    BusinessDomain BusinessDomain,
    bool IsActive,
    int MembershipCount,
    BusinessMemberRole MyRole,
    bool IAmPrimaryOwner,
    byte[] RowVersion);

// No IsActive here on purpose: suspension belongs to SiteAdmin, never to the owner.
public sealed record UpdateBusinessDto(
    string BusinessName,
    string? Description,
    BusinessDomain BusinessDomain,
    string? BusinessAdress,
    string? Website,
    byte[] RowVersion);

public sealed record MemberDto(
    int MembershipId,
    Guid UserId,
    string FullName,
    string Email,
    BusinessMemberRole Role,
    bool IsPrimaryOwner,
    bool IsActive,
    DateTime CreatedAtUtc);

public sealed record AddMemberDto(string Email, BusinessMemberRole Role);
public sealed record ChangeMemberRoleDto(BusinessMemberRole Role);

// What a Client sees: no member counts, no internal flags.
public sealed record PublicBusinessDto(
    int Id,
    string Name,
    string? Description,
    string? Website,
    string? Address,
    BusinessDomain Domain,
    double? AverageRating,
    int RatingCount);

public sealed record RatingDto(byte Stars, string? Comment);

public sealed record RatingView(
    int Id,
    byte Stars,
    string? Comment,
    string ReviewerName,
    DateTime CreatedAtUtc,
    DateTime? UpdatedAtUtc);

// Used for create and update. RowVersion is required on update, ignored on create.
public sealed record SaveContactDto(
    string FirstName,
    string LastName,
    string? Email,
    string? Phone,
    int? CompanyId,
    string? AddressLine,
    string? City,
    string? PostalCode,
    string? Country,
    ContactType ContactType,
    ContactSource ContactSource,
    byte[]? RowVersion);

public sealed record ContactDto(
    int Id,
    string FirstName,
    string LastName,
    string? Email,
    string? Phone,
    int? CompanyId,
    string? AddressLine,
    string? City,
    string? PostalCode,
    string? Country,
    ContactType ContactType,
    ContactSource ContactSource,
    DateTime CreatedAtUtc,
    DateTime? UpdatedAtUtc,
    byte[] RowVersion);

public sealed record PagedResult<T>(IReadOnlyList<T> Items, int Total, int Page, int PageSize);