using MiniCrm.Core.Enums;

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
    public string? Adress {get;set;}
    public bool IsActive { get; set; } = true;           // SiteAdmin can suspend without deleting
    public BusinessDomain Domain {get;set;} = BusinessDomain.Other;
    public bool IsDeleted { get; set; }
    public DateTime? DeletedAtUtc { get; set; }

    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }

    public byte[] RowVersion { get; set; } = null!;

    public ICollection<BusinessMembership> Memberships { get; set; } = [];
    public ICollection<Company> Companies { get; set; } = [];
    public ICollection<Contact> Contacts { get; set; } = [];
    public ICollection<Opportunity> Opportunities { get; set; } = [];
    public ICollection<PipelineStage> PipelineStages { get; set; } = [];
    public ICollection<BusinessRating> RatingsReceived { get; set; } = [];
    public ICollection<ClientRating> ClientRatingsGiven { get; set; } = [];
}
