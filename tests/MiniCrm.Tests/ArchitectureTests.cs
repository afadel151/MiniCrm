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
        Assembly coreAssembly = typeof(ICoreMarker).Assembly;
        AssemblyName[] referencedAssemblies = coreAssembly.GetReferencedAssemblies();

        string[] forbiddenNamespaces = new[]
        {
            "Microsoft.EntityFrameworkCore",
            "Microsoft.AspNetCore.Identity",
            "Microsoft.AspNetCore.Identity.EntityFrameworkCore",
            "MiniCrm.Infrastructure",
            "MiniCrm.Web"
        };

        foreach (AssemblyName refAssembly in referencedAssemblies)
        {
            foreach (string? forbidden in forbiddenNamespaces)
            {
                refAssembly.Name.ShouldNotStartWith(forbidden, customMessage: $"Core assembly must not reference {forbidden}");
            }
        }
    }
}
