using System;

namespace MiniCrm.Core.Services;

public interface ICurrentUser
{
    Guid Id { get; }
    string DisplayName { get; }
    bool IsAdmin { get; }
    void EnsureAuthenticated();
    void EnsureAdmin();
}
