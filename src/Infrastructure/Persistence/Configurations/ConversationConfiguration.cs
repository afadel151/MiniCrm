using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using MiniCrm.Infrastructure.Persistence.Entities;
using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Infrastructure.Persistence.Configurations;

public sealed class ConversationConfiguration : IEntityTypeConfiguration<Conversation>
{
    public void Configure(EntityTypeBuilder<Conversation> builder)
    {
        builder.ToTable("Conversations");

        builder.HasKey(c => c.Id);

        builder.Property(c => c.IsGroup)
            .HasDefaultValue(false);

        builder.Property(c => c.Title)
            .HasMaxLength(Limits.ConversationTitle);

        builder.Property(c => c.DirectKey)
            .HasMaxLength(Limits.ConversationDirectKey);

        builder.Property(c => c.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()");

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(c => c.CreatedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(c => c.DirectKey)
            .IsUnique()
            .HasFilter("DirectKey IS NOT NULL");
    }
}
