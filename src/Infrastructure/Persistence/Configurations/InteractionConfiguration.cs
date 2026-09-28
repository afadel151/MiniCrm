using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using MiniCrm.Infrastructure.Persistence.Entities;
using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Infrastructure.Persistence.Configurations;

public sealed class InteractionConfiguration : IEntityTypeConfiguration<Interaction>
{
    public void Configure(EntityTypeBuilder<Interaction> builder)
    {
        builder.ToTable("Interactions");

        builder.HasKey(i => i.Id);

        builder.Property(i => i.InteractionType)
            .HasColumnType("tinyint");

        builder.Property(i => i.OccurredAtUtc)
            .HasColumnType("datetime2(0)");

        builder.Property(i => i.Subject)
            .HasMaxLength(Limits.InteractionSubject);

        builder.Property(i => i.Notes)
            .HasMaxLength(Limits.InteractionNotes);

        builder.Property(i => i.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()");

        builder.Property(i => i.RowVersion)
            .IsRowVersion();

        builder.HasOne(i => i.Contact)
            .WithMany()
            .HasForeignKey(i => i.ContactId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(i => i.Opportunity)
            .WithMany()
            .HasForeignKey(i => i.OpportunityId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(i => i.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(i => new { i.ContactId, i.OccurredAtUtc });
        builder.HasIndex(i => new { i.UserId, i.OccurredAtUtc });
    }
}
