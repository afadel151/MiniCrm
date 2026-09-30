using System;
using System.Collections.Generic;
using MiniCrm.Core.Enums;
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


    public Guid CreatedByUserId { get; set; }
    public int BusinessId {get;set;}

    public Guid UpdatedByUserId { get; set; }

    public bool IsDeleted { get; set; }

    public ContactType ContactType {get;set;}
    public ContactSource ContactSource {get;set;}
    public DateTime CreatedAtUtc { get; set; }

    public DateTime? UpdatedAtUtc { get; set; }

    public DateTime? DeletedAtUtc { get; set; }

    public byte[] RowVersion { get; set; } = null!;

    public virtual Company? Company { get; set; }
    public virtual Business? Business { get; set; }

    public virtual ApplicationUser CreatedByUser { get; set; } = null!;

    public virtual ICollection<Interaction> Interactions { get; set; } = [];

    public virtual ICollection<Opportunity> Opportunities { get; set; } = [];

    public virtual ICollection<Reminder> Reminders { get; set; } = [];
    public virtual ICollection<Request> Requests { get; set; } = [];

    public virtual ApplicationUser? UpdatedByUser { get; set; }
}
