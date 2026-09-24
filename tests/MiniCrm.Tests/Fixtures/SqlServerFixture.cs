using Testcontainers.MsSql;
using Xunit;

namespace MiniCrm.Tests.Fixtures;

public class SqlServerFixture : IAsyncLifetime
{
    private MsSqlContainer? _container;

    public string ConnectionString => _container?.GetConnectionString() ?? string.Empty;

    public async Task InitializeAsync()
    {
        // Container initialization prepared for integration tests
        _container = new MsSqlBuilder()
            .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
            .Build();

        // Optional: start container if docker is running
        try
        {
            await _container.StartAsync();
        }
        catch
        {
            // Fallback for environments without Docker socket access
        }
    }

    public async Task DisposeAsync()
    {
        if (_container != null)
        {
            await _container.DisposeAsync();
        }
    }
}
