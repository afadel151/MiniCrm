using MiniCrm.Core.Exceptions;
using MiniCrm.Tests.Helpers;
using Shouldly;
using Xunit;

namespace MiniCrm.Tests;

public class CurrentUserTests
{
    [Fact]
    public void Anonymous_User_Throws_UnauthenticatedException()
    {
        var current = TestCurrentUser.Anonymous();
        Should.Throw<UnauthenticatedException>(() => current.EnsureAuthenticated());
    }

    [Fact]
    public void Standard_User_Throws_ForbiddenException_On_EnsureAdmin()
    {
        var current = TestCurrentUser.User();
        current.EnsureAuthenticated();
        Should.Throw<ForbiddenException>(() => current.EnsureAdmin());
    }

    [Fact]
    public void Admin_User_Passes_All_Guards()
    {
        var current = TestCurrentUser.Admin();
        Should.NotThrow(() => current.EnsureAuthenticated());
        Should.NotThrow(() => current.EnsureAdmin());
    }
}
