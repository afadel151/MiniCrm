using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using MiniCrm.Infrastructure.Persistence.Entities;
using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Infrastructure.Persistence.Configurations;

public sealed class RefreshTokenConfiguration : IEntityTypeConfiguration<RefreshToken>
{
    public void Configure(EntityTypeBuilder<RefreshToken> builder)
    {
        builder.ToTable("RefreshTokens");

        builder.HasKey(t => t.Id);

        builder.Property(t => t.TokenHash)
            .IsRequired()
            .HasColumnType($"char({Limits.RefreshTokenHash})");

        builder.Property(t => t.ReplacedByTokenHash)
            .HasColumnType($"char({Limits.RefreshTokenHash})");

        builder.Property(t => t.CreatedByIp)
            .HasMaxLength(Limits.RefreshTokenCreatedByIp);

        builder.Property(t => t.RevokedReason)
            .HasMaxLength(Limits.RefreshTokenRevokedReason);

        builder.Property(t => t.CreatedAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()");

        builder.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(t => t.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(t => t.TokenHash)
            .HasDatabaseName("UX_RefreshTokens_TokenHash")
            .IsUnique();

        builder.HasIndex(t => t.UserId);
    }
}
