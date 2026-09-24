using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace MiniCrm.Infrastructure.Persistence;

public sealed class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args)
    {
        var optionsBuilder = new DbContextOptionsBuilder<AppDbContext>();
        optionsBuilder.UseSqlServer("Server=localhost,1433;Database=MiniCrm;User Id=sa;Password=MiniCrm2026;TrustServerCertificate=True");

        return new AppDbContext(optionsBuilder.Options);
    }
}
