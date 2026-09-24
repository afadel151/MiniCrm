using MiniCrm.Core.Exceptions;
using MiniCrm.Core.Services;

namespace MiniCrm.Tests.Helpers;

public class TestCurrentUser : ICurrentUser
{
    public Guid Id { get; set; } = Guid.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public bool IsAdmin { get; set; }
    public bool IsAuthenticated { get; set; }

    public static TestCurrentUser Anonymous() => new() { IsAuthenticated = false };

    public static TestCurrentUser User(Guid? id = null, string name = "Standard User") => new()
    {
        Id = id ?? Guid.NewGuid(),
        DisplayName = name,
        IsAdmin = false,
        IsAuthenticated = true
    };

    public static TestCurrentUser Admin(Guid? id = null, string name = "Admin User") => new()
    {
        Id = id ?? Guid.NewGuid(),
        DisplayName = name,
        IsAdmin = true,
        IsAuthenticated = true
    };

    public void EnsureAuthenticated()
    {
        if (!IsAuthenticated || Id == Guid.Empty)
        {
            throw new UnauthenticatedException();
        }
    }

    public void EnsureAdmin()
    {
        EnsureAuthenticated();
        if (!IsAdmin)
        {
            throw new ForbiddenException();
        }
    }
}
