namespace MiniCrm.Core.Exceptions;

public abstract class DomainException(int status, string title, string detail) : Exception(detail)
{
    public int Status { get; } = status;
    public string Title { get; } = title;
}

public sealed class NotFoundDomainException(string what) : DomainException(404, "Not found", $"{what} not found.");
public sealed class ForbiddenDomainException(string detail = "You are not allowed to do this.") : DomainException(403, "Forbidden", detail);
public sealed class ConflictDomainException(string detail) : DomainException(409, "Conflict", detail);
public sealed class ValidationDomainException(string detail) : DomainException(400, "Invalid request", detail);

