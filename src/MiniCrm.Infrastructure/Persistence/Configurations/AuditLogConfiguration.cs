using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using MiniCrm.Infrastructure.Persistence.Entities;

namespace MiniCrm.Infrastructure.Persistence.Configurations;

public sealed class AuditLogConfiguration : IEntityTypeConfiguration<AuditLog>
{
    public void Configure(EntityTypeBuilder<AuditLog> builder)
    {
        builder.ToTable("AuditLogs");

        builder.HasKey(a => a.Id);

        builder.Property(a => a.Action)
            .IsRequired()
            .HasMaxLength(Limits.AuditAction);

        builder.Property(a => a.EntityName)
            .HasMaxLength(Limits.AuditEntityName);

        builder.Property(a => a.EntityId)
            .HasMaxLength(Limits.AuditEntityId);

        builder.Property(a => a.IpAddress)
            .HasMaxLength(Limits.AuditIpAddress);

        builder.Property(a => a.OccurredAtUtc)
            .HasDefaultValueSql("SYSUTCDATETIME()");

        builder.HasIndex(a => a.OccurredAtUtc);
        builder.HasIndex(a => new { a.EntityName, a.EntityId });
        builder.HasIndex(a => a.UserId).HasFilter("UserId IS NOT NULL");
    }
}
