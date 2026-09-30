

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