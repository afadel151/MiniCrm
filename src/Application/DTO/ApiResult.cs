using System.ComponentModel.DataAnnotations;

namespace MiniCrm.Application.DTO;

public sealed record ApiResponse<T>(
    T? Data,
    ApiMeta Meta,
    ApiError? Error = null
)
{
    public bool Success => Error is null;
}

public sealed record ApiMeta(
    string RequestId,
    DateTimeOffset Timestamp,
    string ApiVersion,
    PaginationMeta? Pagination = null
);
public sealed record PaginationMeta(
    int Page,
    int PageSize,
    int TotalCount,
    int TotalPages
);

public sealed record ApiError(
    string Code,
    string Message,
    IReadOnlyDictionary<string, string[]>? Details = null
);