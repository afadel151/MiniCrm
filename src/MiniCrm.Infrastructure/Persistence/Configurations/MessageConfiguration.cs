using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using MiniCrm.Infrastructure.Persistence.Entities;
using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Infrastructure.Persistence.Configurations;

public sealed class MessageConfiguration : IEntityTypeConfiguration<Message>
{
    public void Configure(EntityTypeBuilder<Message> builder)
    {
        builder.ToTable("Messages");

        builder.HasKey(m => m.Id);

        builder.Property(m => m.Body)
            .IsRequired()
            .HasMaxLength(Limits.MessageBody);

        builder.Property(m => m.SentAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()");

        builder.Property(m => m.IsDeleted)
            .HasDefaultValue(false);

        builder.HasOne(m => m.Conversation)
            .WithMany(c => c.Messages)
            .HasForeignKey(m => m.ConversationId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(m => m.SenderUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(m => new { m.ConversationId, m.Id });
    }
}
