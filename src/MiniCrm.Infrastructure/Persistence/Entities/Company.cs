using System;
using System.Collections.Generic;
using MiniCrm.Infrastructure.Identity;
namespace MiniCrm.Infrastructure.Persistence.Entities;

public partial class Company
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public string? Website { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public Guid CreatedByUserId { get; set; }

    public DateTime? UpdatedAtUtc { get; set; }

    public Guid? UpdatedByUserId { get; set; }

    public bool IsDeleted { get; set; }

    public DateTime? DeletedAtUtc { get; set; }

    public byte[] RowVersion { get; set; } = null!;

    public virtual ICollection<Contact> Contacts { get; set; } = new List<Contact>();

    public virtual ApplicationUser CreatedByUser { get; set; } = null!;

    public virtual ApplicationUser? UpdatedByUser { get; set; }
}
