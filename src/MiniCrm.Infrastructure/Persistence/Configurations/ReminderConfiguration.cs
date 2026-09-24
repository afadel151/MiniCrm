using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using MiniCrm.Infrastructure.Persistence.Entities;
using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Infrastructure.Persistence.Configurations;

public sealed class ReminderConfiguration : IEntityTypeConfiguration<Reminder>
{
    public void Configure(EntityTypeBuilder<Reminder> builder)
    {
        builder.ToTable("Reminders");

        builder.HasKey(r => r.Id);

        builder.Property(r => r.InteractionType)
            .HasColumnType("tinyint");

        builder.Property(r => r.Status)
            .HasColumnType("tinyint")
            .HasDefaultValue(MiniCrm.Core.Enums.ReminderStatus.Pending);

        builder.Property(r => r.Title)
            .IsRequired()
            .HasMaxLength(Limits.ReminderTitle);

        builder.Property(r => r.Notes)
            .HasMaxLength(Limits.ReminderNotes);

        builder.Property(r => r.DueAtUtc)
            .HasColumnType("datetime2(0)");

        builder.Property(r => r.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()");

        builder.Property(r => r.RowVersion)
            .IsRowVersion();

        builder.HasOne(r => r.Contact)
            .WithMany()
            .HasForeignKey(r => r.ContactId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(r => r.Opportunity)
            .WithMany()
            .HasForeignKey(r => r.OpportunityId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(r => r.AssignedUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(r => r.CreatedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(r => r.DueAtUtc)
            .HasDatabaseName("IX_Reminders_DueScan")
            .HasFilter("Status = 0 AND NotifiedAtUtc IS NULL")
            .IncludeProperties(r => r.AssignedUserId);

        builder.HasIndex(r => new { r.AssignedUserId, r.Status, r.DueAtUtc });
    }
}
