using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using MiniCrm.Infrastructure.Persistence.Entities;
using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Infrastructure.Persistence.Configurations;

public sealed class OpportunityStageHistoryConfiguration : IEntityTypeConfiguration<OpportunityStageHistory>
{
    public void Configure(EntityTypeBuilder<OpportunityStageHistory> builder)
    {
        builder.ToTable("OpportunityStageHistory");

        builder.HasKey(h => h.Id);

        builder.Property(h => h.ChangedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()");

        builder.HasOne(h => h.Opportunity)
            .WithMany()
            .HasForeignKey(h => h.OpportunityId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(h => h.FromStage)
            .WithMany()
            .HasForeignKey(h => h.FromStageId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(h => h.ToStage)
            .WithMany()
            .HasForeignKey(h => h.ToStageId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(h => h.ChangedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(h => new { h.OpportunityId, h.ChangedAtUtc });
        builder.HasIndex(h => h.FromStageId).HasFilter("FromStageId IS NOT NULL");
    }
}
