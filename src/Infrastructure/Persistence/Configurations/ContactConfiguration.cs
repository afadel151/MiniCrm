using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using MiniCrm.Infrastructure.Persistence.Entities;
using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Infrastructure.Persistence.Configurations;

public sealed class ContactConfiguration : IEntityTypeConfiguration<Contact>
{
    public void Configure(EntityTypeBuilder<Contact> builder)
    {
        builder.ToTable("Contacts");

        builder.HasKey(c => c.Id);

        builder.Property(c => c.FirstName)
            .IsRequired()
            .HasMaxLength(Limits.ContactFirstName);

        builder.Property(c => c.LastName)
            .IsRequired()
            .HasMaxLength(Limits.ContactLastName);

        builder.Property(c => c.Email)
            .HasMaxLength(Limits.ContactEmail);

        builder.Property(c => c.Phone)
            .HasMaxLength(Limits.ContactPhone);

        builder.Property(c => c.AddressLine)
            .HasMaxLength(Limits.ContactAddress);

        builder.Property(c => c.City)
            .HasMaxLength(Limits.ContactCity);

        builder.Property(c => c.PostalCode)
            .HasMaxLength(Limits.ContactPostalCode);

        builder.Property(c => c.Country)
            .HasMaxLength(Limits.ContactCountry);

        builder.Property(c => c.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()");

        builder.Property(c => c.IsDeleted)
            .HasDefaultValue(false);

        builder.Property(c => c.RowVersion)
            .IsRowVersion();

        builder.HasOne(c => c.Company)
            .WithMany()
            .HasForeignKey(c => c.CompanyId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(c => c.CreatedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(c => c.UpdatedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(c => c.Email)
            .IsUnique()
            .HasFilter("Email IS NOT NULL AND IsDeleted = 0");

        builder.HasIndex(c => new { c.LastName, c.FirstName })
            .HasFilter("IsDeleted = 0");
    }
}
