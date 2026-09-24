namespace MiniCrm.Core.Services;

public interface IDataSeeder
{
    Task SeedAsync(CancellationToken cancellationToken = default);
}
