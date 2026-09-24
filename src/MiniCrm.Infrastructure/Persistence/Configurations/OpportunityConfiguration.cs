using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using MiniCrm.Infrastructure.Persistence.Entities;
using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Infrastructure.Persistence.Configurations;

public sealed class OpportunityConfiguration : IEntityTypeConfiguration<Opportunity>
{
    public void Configure(EntityTypeBuilder<Opportunity> builder)
    {
        builder.ToTable("Opportunities");

        builder.HasKey(o => o.Id);

        builder.Property(o => o.Title)
            .IsRequired()
            .HasMaxLength(Limits.OpportunityTitle);

        builder.Property(o => o.Amount)
            .HasColumnType("decimal(18,2)")
            .HasDefaultValue(0m);

        builder.Property(o => o.Probability)
            .HasDefaultValue((byte)0);

        builder.Property(o => o.LostReason)
            .HasMaxLength(Limits.OpportunityLostReason);

        builder.Property(o => o.Description)
            .HasMaxLength(Limits.OpportunityDescription);

        builder.Property(o => o.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()");

        builder.Property(o => o.IsDeleted)
            .HasDefaultValue(false);

        builder.Property(o => o.RowVersion)
            .IsRowVersion();

        builder.HasOne(o => o.Contact)
            .WithMany()
            .HasForeignKey(o => o.ContactId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(o => o.Stage)
            .WithMany()
            .HasForeignKey(o => o.StageId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(o => o.OwnerUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(o => o.CreatedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(o => o.UpdatedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(o => o.StageId)
            .HasFilter("IsDeleted = 0")
            .IncludeProperties(o => o.Amount);

        builder.HasIndex(o => o.OwnerUserId)
            .HasFilter("IsDeleted = 0");

        builder.HasIndex(o => o.ExpectedCloseDate)
            .HasFilter("IsDeleted = 0 AND ExpectedCloseDate IS NOT NULL");
    }
}
