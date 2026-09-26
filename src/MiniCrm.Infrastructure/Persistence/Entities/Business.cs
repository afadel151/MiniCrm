namespace MiniCrm.Infrastructure.Persistence.Entities;

/// <summary>
/// The tenant. Created when a Business Owner signs up; owns its own Contacts, Companies (=
/// contacts' employers), Opportunities and PipelineStages. Searchable/rateable by EndClients.
/// </summary>
public class Business
{
    public int Id { get; set; }

    public required string Name { get; set; }          // shown to EndClients in search — unique platform-wide
    public string? Description { get; set; }            // public profile blurb — kept minimal, expand later
    public string? Website { get; set; }

    public bool IsActive { get; set; } = true;           // SiteAdmin can suspend without deleting
    public bool IsDeleted { get; set; }
    public DateTime? DeletedAtUtc { get; set; }

    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }

    public byte[] RowVersion { get; set; } = null!;

    public ICollection<BusinessMembership> Memberships { get; set; } = new List<BusinessMembership>();
    public ICollection<Company> Companies { get; set; } = new List<Company>();
    public ICollection<Contact> Contacts { get; set; } = new List<Contact>();
    public ICollection<Opportunity> Opportunities { get; set; } = new List<Opportunity>();
    public ICollection<PipelineStage> PipelineStages { get; set; } = new List<PipelineStage>();
    public ICollection<BusinessRating> RatingsReceived { get; set; } = new List<BusinessRating>();
    public ICollection<ClientRating> ClientRatingsGiven { get; set; } = new List<ClientRating>();
}
