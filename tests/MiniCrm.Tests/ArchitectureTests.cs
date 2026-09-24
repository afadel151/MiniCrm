using System.Reflection;
using MiniCrm.Core;
using Shouldly;
using Xunit;

namespace MiniCrm.Tests;

public class ArchitectureTests
{
    [Fact]
    public void Core_Assembly_Should_Not_Reference_EntityFramework_Or_Identity()
    {
        var coreAssembly = typeof(ICoreMarker).Assembly;
        var referencedAssemblies = coreAssembly.GetReferencedAssemblies();

        string[] forbiddenNamespaces = new[]
        {
            "Microsoft.EntityFrameworkCore",
            "Microsoft.AspNetCore.Identity",
            "Microsoft.AspNetCore.Identity.EntityFrameworkCore",
            "MiniCrm.Infrastructure",
            "MiniCrm.Web"
        };

        foreach (var refAssembly in referencedAssemblies)
        {
            foreach (string? forbidden in forbiddenNamespaces)
            {
                refAssembly.Name.ShouldNotStartWith(forbidden, customMessage: $"Core assembly must not reference {forbidden}");
            }
        }
    }
}
