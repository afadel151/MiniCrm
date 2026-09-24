using System;
using System.Collections.Generic;
using MiniCrm.Infrastructure.Identity;
namespace MiniCrm.Infrastructure.Persistence.Entities;

public partial class Contact
{
    public int Id { get; set; }

    public string FirstName { get; set; } = null!;

    public string LastName { get; set; } = null!;

    public string? Email { get; set; }

    public string? Phone { get; set; }

    public int? CompanyId { get; set; }

    public string? AddressLine { get; set; }

    public string? City { get; set; }

    public string? PostalCode { get; set; }

    public string? Country { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public Guid CreatedByUserId { get; set; }

    public DateTime? UpdatedAtUtc { get; set; }

    public Guid? UpdatedByUserId { get; set; }

    public bool IsDeleted { get; set; }

    public DateTime? DeletedAtUtc { get; set; }

    public byte[] RowVersion { get; set; } = null!;

    public virtual Company? Company { get; set; }

    public virtual ApplicationUser CreatedByUser { get; set; } = null!;

    public virtual ICollection<Interaction> Interactions { get; set; } = new List<Interaction>();

    public virtual ICollection<Opportunity> Opportunities { get; set; } = new List<Opportunity>();

    public virtual ICollection<Reminder> Reminders { get; set; } = new List<Reminder>();

    public virtual ApplicationUser? UpdatedByUser { get; set; }
}
