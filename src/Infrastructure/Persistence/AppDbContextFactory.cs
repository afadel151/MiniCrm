using Microsoft.EntityFrameworkCore;

namespace MiniCrm.Infrastructure.Persistence;

public sealed class AppDbContextFactory : IDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext()
    {
        var optionsBuilder = new DbContextOptionsBuilder<AppDbContext>();
        optionsBuilder.UseSqlServer("Server=localhost,1433;Database=MiniCrm;User Id=sa;Password=MiniCrm2026;TrustServerCertificate=True");

        return new AppDbContext(optionsBuilder.Options);
    }
}
