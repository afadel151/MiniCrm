using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using MiniCrm.Infrastructure.Identity;
using MiniCrm.Infrastructure.Persistence.Entities;

namespace MiniCrm.Infrastructure.Persistence;

public partial class AppDbContext(DbContextOptions<AppDbContext> options) : IdentityDbContext<ApplicationUser, ApplicationRole, Guid>(options)
{
    public virtual DbSet<SellerRating> SellerRatings { get; set; }
    public virtual DbSet<AuditLog> AuditLogs { get; set; }
    public virtual DbSet<Company> Companies { get; set; }
    public virtual DbSet<Contact> Contacts { get; set; }
    public virtual DbSet<Conversation> Conversations { get; set; }
    public virtual DbSet<ConversationParticipant> ConversationParticipants { get; set; }
    public virtual DbSet<Interaction> Interactions { get; set; }
    public virtual DbSet<Message> Messages { get; set; }
    public virtual DbSet<Opportunity> Opportunities { get; set; }
    public virtual DbSet<OpportunityStageHistory> OpportunityStageHistories { get; set; }
    public virtual DbSet<PipelineStage> PipelineStages { get; set; }
    public virtual DbSet<RefreshToken> RefreshTokens { get; set; }
    public virtual DbSet<Reminder> Reminders { get; set; }

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder); // must be first: maps all Identity tables, indexes, max lengths

        builder.UseCollation("Latin1_General_100_CI_AI");

        builder.Entity<ApplicationRole>(entity =>
        {
            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())", "DF_AspNetRoles_Id");
        });

        builder.Entity<ApplicationUser>(entity =>
        {
            entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())", "DF_AspNetUsers_Id");
            entity.Property(e => e.FirstName).HasMaxLength(100);
            entity.Property(e => e.LastName).HasMaxLength(100);
            entity.Property(e => e.CreatedAtUtc)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())", "DF_AspNetUsers_CreatedAtUtc");
            entity.Property(e => e.LastLoginAtUtc).HasPrecision(3);
        });
        builder.Entity<SellerRating>(entity =>
        {
            entity.ToTable(t =>
            {
                t.HasCheckConstraint("CK_SellerRatings_Stars", "[Stars] BETWEEN 1 AND 5");
                t.HasCheckConstraint("CK_SellerRatings_NotSelf", "[SellerUserId] <> [ClientUserId]");
            });

            entity.HasIndex(e => new { e.SellerUserId, e.ClientUserId }, "UX_SellerRatings_Seller_Client").IsUnique();
            entity.HasIndex(e => e.ClientUserId, "IX_SellerRatings_ClientUserId");

            entity.Property(e => e.Comment).HasMaxLength(1000);
            entity.Property(e => e.CreatedAtUtc)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())", "DF_SellerRatings_CreatedAtUtc");
            entity.Property(e => e.UpdatedAtUtc).HasPrecision(3);

            entity.HasOne<ApplicationUser>().WithMany()
                .HasForeignKey(e => e.SellerUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne<ApplicationUser>().WithMany()
                .HasForeignKey(e => e.ClientUserId)
                .OnDelete(DeleteBehavior.Restrict);
        });
        builder.Entity<AuditLog>(entity =>
        {
            entity.HasIndex(e => new { e.EntityName, e.EntityId }, "IX_AuditLogs_Entity");
            entity.HasIndex(e => e.OccurredAtUtc, "IX_AuditLogs_OccurredAtUtc").IsDescending();
            entity.HasIndex(e => e.UserId, "IX_AuditLogs_UserId").HasFilter("([UserId] IS NOT NULL)");
            entity.ToTable(t => t.HasCheckConstraint("CK_AuditLogs_DetailsJson", "[Details] IS NULL OR ISJSON([Details]) = 1"));
            entity.Property(e => e.Action).HasMaxLength(50);
            entity.Property(e => e.EntityId).HasMaxLength(50);
            entity.Property(e => e.EntityName).HasMaxLength(100);
            entity.Property(e => e.IpAddress).HasMaxLength(45);
            entity.Property(e => e.OccurredAtUtc)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())", "DF_AuditLogs_OccurredAtUtc");
        });

        builder.Entity<Company>(entity =>
        {
            entity.HasIndex(e => e.CreatedByUserId, "IX_Companies_CreatedByUserId");
            entity.HasIndex(e => e.UpdatedByUserId, "IX_Companies_UpdatedByUserId").HasFilter("([UpdatedByUserId] IS NOT NULL)");
            entity.HasIndex(e => e.Name, "UX_Companies_Name").IsUnique().HasFilter("([IsDeleted]=(0))");
            entity.ToTable(t => t.HasCheckConstraint("CK_Companies_Deleted",
                "([IsDeleted] = 0 AND [DeletedAtUtc] IS NULL) OR ([IsDeleted] = 1 AND [DeletedAtUtc] IS NOT NULL)"));
            entity.Property(e => e.CreatedAtUtc)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())", "DF_Companies_CreatedAtUtc");
            entity.Property(e => e.DeletedAtUtc).HasPrecision(3);
            entity.Property(e => e.Name).HasMaxLength(200);
            entity.Property(e => e.RowVersion).IsRowVersion().IsConcurrencyToken();
            entity.Property(e => e.UpdatedAtUtc).HasPrecision(3);
            entity.Property(e => e.Website).HasMaxLength(255);

            entity.HasOne(d => d.CreatedByUser).WithMany()
                .HasForeignKey(d => d.CreatedByUserId)
                .OnDelete(DeleteBehavior.ClientSetNull);

            entity.HasOne(d => d.UpdatedByUser).WithMany().HasForeignKey(d => d.UpdatedByUserId);
        });

        builder.Entity<Contact>(entity =>
        {
            entity.HasIndex(e => e.CompanyId, "IX_Contacts_CompanyId");
            entity.HasIndex(e => e.CreatedByUserId, "IX_Contacts_CreatedByUserId");
            entity.HasIndex(e => new { e.LastName, e.FirstName }, "IX_Contacts_LastName_FirstName").HasFilter("([IsDeleted]=(0))");
            entity.HasIndex(e => e.UpdatedByUserId, "IX_Contacts_UpdatedByUserId").HasFilter("([UpdatedByUserId] IS NOT NULL)");
            entity.HasIndex(e => e.Email, "UX_Contacts_Email").IsUnique().HasFilter("([Email] IS NOT NULL AND [IsDeleted]=(0))");
            entity.ToTable(t => t.HasCheckConstraint("CK_Contacts_Deleted",
                "([IsDeleted] = 0 AND [DeletedAtUtc] IS NULL) OR ([IsDeleted] = 1 AND [DeletedAtUtc] IS NOT NULL)"));

            entity.Property(e => e.AddressLine).HasMaxLength(200);
            entity.Property(e => e.City).HasMaxLength(100);
            entity.Property(e => e.Country).HasMaxLength(100);
            entity.Property(e => e.CreatedAtUtc)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())", "DF_Contacts_CreatedAtUtc");
            entity.Property(e => e.DeletedAtUtc).HasPrecision(3);
            entity.Property(e => e.Email).HasMaxLength(256);
            entity.Property(e => e.FirstName).HasMaxLength(100);
            entity.Property(e => e.LastName).HasMaxLength(100);
            entity.Property(e => e.Phone).HasMaxLength(30);
            entity.Property(e => e.PostalCode).HasMaxLength(20);
            entity.Property(e => e.RowVersion).IsRowVersion().IsConcurrencyToken();
            entity.Property(e => e.UpdatedAtUtc).HasPrecision(3);

            entity.HasOne(d => d.Company).WithMany(p => p.Contacts).HasForeignKey(d => d.CompanyId);

            entity.HasOne(d => d.CreatedByUser).WithMany()
                .HasForeignKey(d => d.CreatedByUserId)
                .OnDelete(DeleteBehavior.ClientSetNull);

            entity.HasOne(d => d.UpdatedByUser).WithMany().HasForeignKey(d => d.UpdatedByUserId);
        });

        builder.Entity<Conversation>(entity =>
        {
            entity.HasIndex(e => e.CreatedByUserId, "IX_Conversations_CreatedByUserId");
            entity.HasIndex(e => e.DirectKey, "UX_Conversations_DirectKey").IsUnique().HasFilter("([DirectKey] IS NOT NULL)");
            entity.ToTable(t => t.HasCheckConstraint("CK_Conversations_Kind",
                "([IsGroup] = 1 AND [DirectKey] IS NULL) OR ([IsGroup] = 0 AND [DirectKey] IS NOT NULL)"));

            entity.Property(e => e.CreatedAtUtc)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())", "DF_Conversations_CreatedAtUtc");
            entity.Property(e => e.DirectKey).HasMaxLength(80);
            entity.Property(e => e.Title).HasMaxLength(200);

            entity.HasOne(d => d.CreatedByUser).WithMany()
                .HasForeignKey(d => d.CreatedByUserId)
                .OnDelete(DeleteBehavior.ClientSetNull);
        });

        builder.Entity<ConversationParticipant>(entity =>
        {
            entity.HasKey(e => new { e.ConversationId, e.UserId });
            entity.HasIndex(e => e.UserId, "IX_ConvParticipants_UserId");

            entity.Property(e => e.JoinedAtUtc)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())", "DF_ConvParticipants_JoinedAtUtc");

            entity.HasOne(d => d.Conversation).WithMany(p => p.ConversationParticipants)
                .HasForeignKey(d => d.ConversationId)
                .HasConstraintName("FK_ConvParticipants_Conversations_ConversationId");

            entity.HasOne(d => d.User).WithMany()
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ConvParticipants_AspNetUsers_UserId");
        });

        builder.Entity<Interaction>(entity =>
        {
            entity.HasIndex(e => new { e.ContactId, e.OccurredAtUtc }, "IX_Interactions_ContactId_OccurredAtUtc").IsDescending(false, true);
            entity.HasIndex(e => e.OpportunityId, "IX_Interactions_OpportunityId").HasFilter("([OpportunityId] IS NOT NULL)");
            entity.HasIndex(e => new { e.UserId, e.OccurredAtUtc }, "IX_Interactions_UserId_OccurredAtUtc").IsDescending(false, true);
            entity.ToTable(t => t.HasCheckConstraint("CK_Interactions_Type", "[InteractionType] IN (1, 2, 3)"));

            entity.Property(e => e.CreatedAtUtc)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())", "DF_Interactions_CreatedAtUtc");
            entity.Property(e => e.Notes).HasMaxLength(4000);
            entity.Property(e => e.OccurredAtUtc).HasPrecision(0);
            entity.Property(e => e.RowVersion).IsRowVersion().IsConcurrencyToken();
            entity.Property(e => e.Subject).HasMaxLength(200);
            entity.Property(e => e.UpdatedAtUtc).HasPrecision(3);

            entity.HasOne(d => d.Contact).WithMany(p => p.Interactions).HasForeignKey(d => d.ContactId);

            entity.HasOne(d => d.Opportunity).WithMany(p => p.Interactions)
                .HasForeignKey(d => d.OpportunityId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(d => d.User).WithMany()
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull);
        });

        builder.Entity<Message>(entity =>
        {
            entity.HasIndex(e => new { e.ConversationId, e.Id }, "IX_Messages_ConversationId_Id").IsDescending(false, true);
            entity.HasIndex(e => e.SenderUserId, "IX_Messages_SenderUserId");
            entity.ToTable(t => t.HasCheckConstraint("CK_Messages_BodyNotEmpty", "LEN(LTRIM(RTRIM([Body]))) > 0"));

            entity.Property(e => e.Body).HasMaxLength(4000);
            entity.Property(e => e.EditedAtUtc).HasPrecision(3);
            entity.Property(e => e.SentAtUtc)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())", "DF_Messages_SentAtUtc");

            entity.HasOne(d => d.Conversation).WithMany(p => p.Messages).HasForeignKey(d => d.ConversationId);

            entity.HasOne(d => d.SenderUser).WithMany()
                .HasForeignKey(d => d.SenderUserId)
                .OnDelete(DeleteBehavior.ClientSetNull);
        });

        builder.Entity<Opportunity>(entity =>
        {
            entity.HasIndex(e => e.ContactId, "IX_Opportunities_ContactId");
            entity.HasIndex(e => e.CreatedByUserId, "IX_Opportunities_CreatedByUserId");
            entity.HasIndex(e => e.ExpectedCloseDate, "IX_Opportunities_ExpectedCloseDate").HasFilter("([IsDeleted]=(0) AND [ExpectedCloseDate] IS NOT NULL)");
            entity.HasIndex(e => e.OwnerUserId, "IX_Opportunities_OwnerUserId").HasFilter("([IsDeleted]=(0))");
            entity.HasIndex(e => e.StageId, "IX_Opportunities_StageId").HasFilter("([IsDeleted]=(0))");
            entity.ToTable(t =>
            {
                t.HasCheckConstraint("CK_Opportunities_Amount", "[Amount] >= 0");
                t.HasCheckConstraint("CK_Opportunities_Probability", "[Probability] BETWEEN 0 AND 100");
                t.HasCheckConstraint("CK_Opportunities_Deleted",
                    "([IsDeleted] = 0 AND [DeletedAtUtc] IS NULL) OR ([IsDeleted] = 1 AND [DeletedAtUtc] IS NOT NULL)");
            });
            entity.Property(e => e.Amount).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.ClosedAtUtc).HasPrecision(3);
            entity.Property(e => e.CreatedAtUtc)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())", "DF_Opportunities_CreatedAtUtc");
            entity.Property(e => e.DeletedAtUtc).HasPrecision(3);
            entity.Property(e => e.Description).HasMaxLength(2000);
            entity.Property(e => e.LostReason).HasMaxLength(500);
            entity.Property(e => e.RowVersion).IsRowVersion().IsConcurrencyToken();
            entity.Property(e => e.Title).HasMaxLength(200);
            entity.Property(e => e.UpdatedAtUtc).HasPrecision(3);

            entity.HasOne(d => d.Contact).WithMany(p => p.Opportunities)
                .HasForeignKey(d => d.ContactId)
                .OnDelete(DeleteBehavior.ClientSetNull);

            entity.HasOne(d => d.CreatedByUser).WithMany()
                .HasForeignKey(d => d.CreatedByUserId)
                .OnDelete(DeleteBehavior.ClientSetNull);

            entity.HasOne(d => d.OwnerUser).WithMany()
                .HasForeignKey(d => d.OwnerUserId)
                .OnDelete(DeleteBehavior.ClientSetNull);

            entity.HasOne(d => d.Stage).WithMany(p => p.Opportunities)
                .HasForeignKey(d => d.StageId)
                .OnDelete(DeleteBehavior.ClientSetNull);

            entity.HasOne(d => d.UpdatedByUser).WithMany().HasForeignKey(d => d.UpdatedByUserId);
        });

        builder.Entity<OpportunityStageHistory>(entity =>
        {
            entity.ToTable("OpportunityStageHistory");

            entity.HasIndex(e => e.ChangedByUserId, "IX_OppStageHistory_ChangedByUserId");
            entity.HasIndex(e => e.FromStageId, "IX_OppStageHistory_FromStageId").HasFilter("([FromStageId] IS NOT NULL)");
            entity.HasIndex(e => new { e.OpportunityId, e.ChangedAtUtc }, "IX_OppStageHistory_OpportunityId_ChangedAtUtc");
            entity.HasIndex(e => e.ToStageId, "IX_OppStageHistory_ToStageId");

            entity.Property(e => e.ChangedAtUtc)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())", "DF_OppStageHistory_ChangedAtUtc");

            entity.HasOne(d => d.ChangedByUser).WithMany()
                .HasForeignKey(d => d.ChangedByUserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_OppStageHistory_AspNetUsers_ChangedByUserId");

            entity.HasOne(d => d.FromStage).WithMany(p => p.OpportunityStageHistoryFromStages)
                .HasForeignKey(d => d.FromStageId)
                .HasConstraintName("FK_OppStageHistory_PipelineStages_FromStageId");

            entity.HasOne(d => d.Opportunity).WithMany(p => p.OpportunityStageHistories)
                .HasForeignKey(d => d.OpportunityId)
                .HasConstraintName("FK_OppStageHistory_Opportunities_OpportunityId");

            entity.HasOne(d => d.ToStage).WithMany(p => p.OpportunityStageHistoryToStages)
                .HasForeignKey(d => d.ToStageId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_OppStageHistory_PipelineStages_ToStageId");
        });

        builder.Entity<PipelineStage>(entity =>
        {
            entity.HasIndex(e => e.Name, "UX_PipelineStages_Name").IsUnique();
            entity.ToTable(t =>
            {
                t.HasCheckConstraint("CK_PipelineStages_Probability", "[DefaultProbability] BETWEEN 0 AND 100");
                t.HasCheckConstraint("CK_PipelineStages_WonLost", "NOT ([IsWon] = 1 AND [IsLost] = 1)");
            });
            entity.Property(e => e.IsActive).HasDefaultValue(true, "DF_PipelineStages_IsActive");
            entity.Property(e => e.Name).HasMaxLength(100);
        });

        builder.Entity<RefreshToken>(entity =>
        {
            entity.HasIndex(e => e.UserId, "IX_RefreshTokens_UserId");
            entity.HasIndex(e => e.TokenHash, "UX_RefreshTokens_TokenHash").IsUnique();

            entity.Property(e => e.CreatedAtUtc)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())", "DF_RefreshTokens_CreatedAtUtc");
            entity.Property(e => e.CreatedByIp).HasMaxLength(45);
            entity.Property(e => e.ExpiresAtUtc).HasPrecision(3);
            entity.Property(e => e.ReplacedByTokenHash)
                .HasMaxLength(64)
                .IsUnicode(false)
                .IsFixedLength();
            entity.Property(e => e.RevokedAtUtc).HasPrecision(3);
            entity.Property(e => e.RevokedReason).HasMaxLength(100);
            entity.Property(e => e.TokenHash)
                .HasMaxLength(64)
                .IsUnicode(false)
                .IsFixedLength();

            entity.HasOne(d => d.User).WithMany().HasForeignKey(d => d.UserId);
        });

        builder.Entity<Reminder>(entity =>
        {
            entity.HasIndex(e => new { e.AssignedUserId, e.Status, e.DueAtUtc }, "IX_Reminders_AssignedUserId_Status_DueAtUtc");
            entity.HasIndex(e => e.ContactId, "IX_Reminders_ContactId");
            entity.HasIndex(e => e.CreatedByUserId, "IX_Reminders_CreatedByUserId");
            entity.HasIndex(e => e.DueAtUtc, "IX_Reminders_DueScan").HasFilter("([Status]=(0) AND [NotifiedAtUtc] IS NULL)");
            entity.HasIndex(e => e.OpportunityId, "IX_Reminders_OpportunityId").HasFilter("([OpportunityId] IS NOT NULL)");
            entity.ToTable(t =>
            {
                t.HasCheckConstraint("CK_Reminders_Type", "[InteractionType] IN (1, 2, 3)");
                t.HasCheckConstraint("CK_Reminders_Status", "[Status] IN (0, 1, 2)");
                t.HasCheckConstraint("CK_Reminders_Completed",
                    "([Status] = 1 AND [CompletedAtUtc] IS NOT NULL) OR ([Status] <> 1 AND [CompletedAtUtc] IS NULL)");
            });
            entity.Property(e => e.CompletedAtUtc).HasPrecision(3);
            entity.Property(e => e.CreatedAtUtc)
                .HasPrecision(3)
                .HasDefaultValueSql("(sysutcdatetime())", "DF_Reminders_CreatedAtUtc");
            entity.Property(e => e.DueAtUtc).HasPrecision(0);
            entity.Property(e => e.Notes).HasMaxLength(2000);
            entity.Property(e => e.NotifiedAtUtc).HasPrecision(3);
            entity.Property(e => e.RowVersion).IsRowVersion().IsConcurrencyToken();
            entity.Property(e => e.Title).HasMaxLength(200);

            entity.HasOne(d => d.AssignedUser).WithMany()
                .HasForeignKey(d => d.AssignedUserId)
                .OnDelete(DeleteBehavior.ClientSetNull);

            entity.HasOne(d => d.Contact).WithMany(p => p.Reminders).HasForeignKey(d => d.ContactId);

            entity.HasOne(d => d.CreatedByUser).WithMany()
                .HasForeignKey(d => d.CreatedByUserId)
                .OnDelete(DeleteBehavior.ClientSetNull);

            entity.HasOne(d => d.Opportunity).WithMany(p => p.Reminders)
                .HasForeignKey(d => d.OpportunityId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        OnModelCreatingPartial(builder);
    }

    partial void OnModelCreatingPartial(ModelBuilder builder);
}