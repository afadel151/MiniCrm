// ============================================================================
// MERGE GUIDE — apply these changes to your existing AppDbContext.cs.
// This is NOT a standalone file; it will not compile on its own. Each numbered
// block below tells you exactly what to add/change and where.
// ============================================================================

// ----------------------------------------------------------------------------
// 1) CONSTRUCTOR — inject ICurrentTenantAccessor so global query filters can
//    read it. This is the single biggest change: without it, tenant isolation
//    has to be re-checked by hand in every service method instead of being
//    impossible to forget.
// ----------------------------------------------------------------------------
//
// BEFORE:
//   public partial class AppDbContext(DbContextOptions<AppDbContext> options)
//       : IdentityDbContext<ApplicationUser, ApplicationRole, Guid>(options)
//   {
//
// AFTER:
//   public partial class AppDbContext(
//       DbContextOptions<AppDbContext> options,
//       ICurrentTenantAccessor tenant)
//       : IdentityDbContext<ApplicationUser, ApplicationRole, Guid>(options)
//   {
//       private readonly ICurrentTenantAccessor _tenant = tenant;
//
// IMPORTANT — this breaks `dotnet ef migrations add` unless AppDbContextFactory.cs
// (your IDesignTimeDbContextFactory) also supplies an ICurrentTenantAccessor.
// At design time there is no HTTP request, so pass a stub that allows everything:
//
//   internal sealed class DesignTimeTenantAccessor : ICurrentTenantAccessor
//   {
//       public int? BusinessId => null;
//       public bool IsSiteAdmin => true;   // migrations must see the full model, unfiltered
//       public Guid? UserId => null;
//   }
//
//   // in AppDbContextFactory.CreateDbContext(...):
//   return new AppDbContext(optionsBuilder.Options, new DesignTimeTenantAccessor());


// ----------------------------------------------------------------------------
// 2) NEW DbSets — add alongside your existing ones.
// ----------------------------------------------------------------------------
//
//   public virtual DbSet<Business> Businesses { get; set; }
//   public virtual DbSet<BusinessMembership> BusinessMemberships { get; set; }
//   public virtual DbSet<BusinessRating> BusinessRatings { get; set; }
//   public virtual DbSet<ClientRating> ClientRatings { get; set; }
//
// REMOVE (or keep only if you decide the seller/client concept from before still
// applies to something else — confirm before deleting): DbSet<SellerRating>,
// and its config block in OnModelCreating. It's superseded by BusinessRating/ClientRating.


// ----------------------------------------------------------------------------
// 3) EXISTING ENTITIES — add these properties (in the .cs files, not here):
// ----------------------------------------------------------------------------
//
//   Company.cs, Contact.cs, Opportunity.cs, PipelineStage.cs — add:
//     public int BusinessId { get; set; }
//     public Business Business { get; set; } = null!;
//
//   AuditLog.cs — add (nullable: SiteAdmin actions aren't tenant-scoped):
//     public int? BusinessId { get; set; }
//     public Business? Business { get; set; }
//
// Interaction and Reminder deliberately do NOT get a BusinessId column — they're
// already reachable through Contact/Opportunity, which are tenant-filtered. Adding
// a redundant BusinessId there risks drifting out of sync with the parent's tenant.


// ----------------------------------------------------------------------------
// 4) OnModelCreating — add these entity configs (order doesn't matter, but keep
//    them with the other builder.Entity<T>(...) blocks):
// ----------------------------------------------------------------------------

/*
builder.Entity<Business>(entity =>
{
    entity.HasIndex(e => e.Name, "UX_Businesses_Name").IsUnique().HasFilter("([IsDeleted]=(0))");
    entity.ToTable(t => t.HasCheckConstraint("CK_Businesses_Deleted",
        "([IsDeleted] = 0 AND [DeletedAtUtc] IS NULL) OR ([IsDeleted] = 1 AND [DeletedAtUtc] IS NOT NULL)"));

    entity.Property(e => e.Name).HasMaxLength(200);
    entity.Property(e => e.Description).HasMaxLength(2000);
    entity.Property(e => e.Website).HasMaxLength(255);
    entity.Property(e => e.CreatedAtUtc).HasPrecision(3).HasDefaultValueSql("(sysutcdatetime())", "DF_Businesses_CreatedAtUtc");
    entity.Property(e => e.UpdatedAtUtc).HasPrecision(3);
    entity.Property(e => e.DeletedAtUtc).HasPrecision(3);
    entity.Property(e => e.RowVersion).IsRowVersion().IsConcurrencyToken();
});

builder.Entity<BusinessMembership>(entity =>
{
    // One membership row per user per business — a user cannot join the same tenant twice.
    entity.HasIndex(e => new { e.BusinessId, e.UserId }, "UX_BusinessMemberships_Business_User").IsUnique();
    entity.HasIndex(e => e.UserId, "IX_BusinessMemberships_UserId");
    entity.Property(e => e.CreatedAtUtc).HasPrecision(3).HasDefaultValueSql("(sysutcdatetime())", "DF_BusinessMemberships_CreatedAtUtc");

    entity.HasOne(d => d.Business).WithMany(p => p.Memberships).HasForeignKey(d => d.BusinessId);
    entity.HasOne(d => d.User).WithMany().HasForeignKey(d => d.UserId).OnDelete(DeleteBehavior.Restrict);
});

builder.Entity<BusinessRating>(entity =>
{
    entity.ToTable(t => t.HasCheckConstraint("CK_BusinessRatings_Stars", "[Stars] BETWEEN 1 AND 5"));
    entity.HasIndex(e => new { e.BusinessId, e.ClientUserId }, "UX_BusinessRatings_Business_Client").IsUnique();
    entity.HasIndex(e => e.ClientUserId, "IX_BusinessRatings_ClientUserId");

    entity.Property(e => e.Comment).HasMaxLength(1000);
    entity.Property(e => e.CreatedAtUtc).HasPrecision(3).HasDefaultValueSql("(sysutcdatetime())", "DF_BusinessRatings_CreatedAtUtc");
    entity.Property(e => e.UpdatedAtUtc).HasPrecision(3);

    entity.HasOne(d => d.Business).WithMany(p => p.RatingsReceived).HasForeignKey(d => d.BusinessId);
    entity.HasOne(d => d.ClientUser).WithMany().HasForeignKey(d => d.ClientUserId).OnDelete(DeleteBehavior.Restrict);
});

builder.Entity<ClientRating>(entity =>
{
    entity.ToTable(t => t.HasCheckConstraint("CK_ClientRatings_Stars", "[Stars] BETWEEN 1 AND 5"));
    entity.HasIndex(e => new { e.BusinessId, e.ClientUserId }, "UX_ClientRatings_Business_Client").IsUnique();
    entity.HasIndex(e => e.ClientUserId, "IX_ClientRatings_ClientUserId");

    entity.Property(e => e.Comment).HasMaxLength(1000);
    entity.Property(e => e.CreatedAtUtc).HasPrecision(3).HasDefaultValueSql("(sysutcdatetime())", "DF_ClientRatings_CreatedAtUtc");
    entity.Property(e => e.UpdatedAtUtc).HasPrecision(3);

    entity.HasOne(d => d.Business).WithMany(p => p.ClientRatingsGiven).HasForeignKey(d => d.BusinessId);
    entity.HasOne(d => d.ClientUser).WithMany().HasForeignKey(d => d.ClientUserId).OnDelete(DeleteBehavior.Restrict);
    entity.HasOne(d => d.RatedByUser).WithMany().HasForeignKey(d => d.RatedByUserId).OnDelete(DeleteBehavior.Restrict);
});

// --- Rescope existing entities onto Business ---

// Company: was globally unique by name; now unique PER TENANT. Drop the old filtered index
// and replace it — a global unique index here is exactly the bug described at the top of this task.
builder.Entity<Company>(entity =>
{
    entity.HasIndex(e => e.BusinessId, "IX_Companies_BusinessId");
    entity.HasIndex(e => new { e.BusinessId, e.Name }, "UX_Companies_Business_Name").IsUnique().HasFilter("([IsDeleted]=(0))");
    // DELETE your old "UX_Companies_Name" single-column unique index — replaced by the composite one above.
    entity.HasOne(d => d.Business).WithMany(p => p.Companies).HasForeignKey(d => d.BusinessId).OnDelete(DeleteBehavior.Restrict);
});

builder.Entity<Contact>(entity =>
{
    entity.HasIndex(e => e.BusinessId, "IX_Contacts_BusinessId");
    // Email uniqueness also needs rescoping per-tenant for the same reason as Company.Name:
    // DELETE the old "UX_Contacts_Email" and replace with:
    entity.HasIndex(e => new { e.BusinessId, e.Email }, "UX_Contacts_Business_Email")
        .IsUnique().HasFilter("([Email] IS NOT NULL AND [IsDeleted]=(0))");
    entity.HasOne(d => d.Business).WithMany(p => p.Contacts).HasForeignKey(d => d.BusinessId).OnDelete(DeleteBehavior.Restrict);
});

builder.Entity<Opportunity>(entity =>
{
    entity.HasIndex(e => e.BusinessId, "IX_Opportunities_BusinessId");
    entity.HasOne(d => d.Business).WithMany(p => p.Opportunities).HasForeignKey(d => d.BusinessId).OnDelete(DeleteBehavior.Restrict);
});

builder.Entity<PipelineStage>(entity =>
{
    entity.HasIndex(e => e.BusinessId, "IX_PipelineStages_BusinessId");
    // DELETE the old global "UX_PipelineStages_Name" — each Business customizes its own pipeline:
    entity.HasIndex(e => new { e.BusinessId, e.Name }, "UX_PipelineStages_Business_Name").IsUnique();
    entity.HasOne(d => d.Business).WithMany(p => p.PipelineStages).HasForeignKey(d => d.BusinessId).OnDelete(DeleteBehavior.Restrict);
});

builder.Entity<AuditLog>(entity =>
{
    entity.HasIndex(e => e.BusinessId, "IX_AuditLogs_BusinessId").HasFilter("([BusinessId] IS NOT NULL)");
    entity.HasOne(d => d.Business).WithMany().HasForeignKey(d => d.BusinessId).OnDelete(DeleteBehavior.Restrict);
});

// --- Global query filters: the actual tenant-isolation enforcement ---
// SiteAdmin sees everything unfiltered; everyone else sees only their own Business's rows.
// A user with no BusinessId (EndClient) sees none of these — correct, they have no tenant data.

builder.Entity<Company>().HasQueryFilter(e => _tenant.IsSiteAdmin || e.BusinessId == _tenant.BusinessId);
builder.Entity<Contact>().HasQueryFilter(e => _tenant.IsSiteAdmin || e.BusinessId == _tenant.BusinessId);
builder.Entity<Opportunity>().HasQueryFilter(e => _tenant.IsSiteAdmin || e.BusinessId == _tenant.BusinessId);
builder.Entity<PipelineStage>().HasQueryFilter(e => _tenant.IsSiteAdmin || e.BusinessId == _tenant.BusinessId);

// NOTE: Interaction/Reminder are NOT given their own query filter here — EF Core does not
// automatically chain a parent's filter through a navigation on its own. Until you add
// `.Include(i => i.Contact)` and filter explicitly, a raw `db.Interactions` query is NOT
// tenant-scoped. Every IInteractionService/IReminderService method must filter through
// Contact/Opportunity explicitly, e.g.:
//   db.Interactions.Where(i => i.Contact.BusinessId == _tenant.BusinessId)
// Put this in the plan as an explicit test, not something to trust by convention.
*/
