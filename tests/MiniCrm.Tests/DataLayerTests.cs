using Microsoft.EntityFrameworkCore;
using  MiniCrm.Infrastructure.Persistence.Entities;
using MiniCrm.Core.Services;
using MiniCrm.Infrastructure.Persistence;
using MiniCrm.Infrastructure.Services;
using Shouldly;
using Xunit;

namespace MiniCrm.Tests;

public sealed class DataLayerTests
{
    private static AppDbContext CreateInMemoryDbContext()
    {
        DbContextOptions<AppDbContext> options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        return new AppDbContext(options);
    }

    [Fact]
    public async Task SoftDelete_GlobalQueryFilter_HidesDeletedRecords()
    {
        // Arrange
        await using AppDbContext db = CreateInMemoryDbContext();
        var company = new Company
        {
            Name = "Acme Corp",
            CreatedByUserId = Guid.NewGuid(),
            CreatedAtUtc = DateTime.UtcNow,
            IsDeleted = true,
            DeletedAtUtc = DateTime.UtcNow
        };

        db.Companies.Add(company);
        await db.SaveChangesAsync();

        // Act
        List<Company> activeCompanies = await db.Companies.ToListAsync();
        List<Company> allCompanies = await db.Companies.IgnoreQueryFilters().ToListAsync();

        // Assert
        activeCompanies.ShouldBeEmpty();
        allCompanies.Count.ShouldBe(1);
    }

    [Fact]
    public void Stamp_Created_And_Deleted_UpdatesEntityFields()
    {
        // Arrange
        var contact = new Contact { FirstName = "John", LastName = "Doe" };
        var userId = Guid.NewGuid();
        DateTime now = DateTime.UtcNow;

        // Act
        Stamp.Created(contact, userId, now);

        // Assert
        contact.CreatedByUserId.ShouldBe(userId);
        contact.CreatedAtUtc.ShouldBe(now);

        // Act - Delete
        Stamp.Deleted(contact, userId, now.AddMinutes(5));

        // Assert
        contact.IsDeleted.ShouldBeTrue();
        contact.DeletedAtUtc.ShouldBe(now.AddMinutes(5));
        contact.UpdatedByUserId.ShouldBe(userId);
    }

    [Fact]
    public void AuditService_SerializeAndSanitize_StripsPasswordAndTokenKeys()
    {
        // Arrange
        var details = new
        {
            Username = "johndoe",
            Password = "SuperSecretPassword123!",
            Token = "jwt.token.value",
            Nested = new
            {
                PasswordHash = "hash12345",
                Address = "123 Main St"
            }
        };

        // Act
        string sanitizedJson = AuditService.SerializeAndSanitize(details);

        // Assert
        sanitizedJson.ShouldNotContain("SuperSecretPassword123!");
        sanitizedJson.ShouldNotContain("jwt.token.value");
        sanitizedJson.ShouldNotContain("hash12345");
        sanitizedJson.ShouldContain("johndoe");
        sanitizedJson.ShouldContain("123 Main St");
    }
}
