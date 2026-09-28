using System;
using System.Collections.Generic;
using MiniCrm.Infrastructure.Identity;
namespace MiniCrm.Infrastructure.Persistence.Entities;

public partial class Conversation
{
    public int Id { get; set; }

    public bool IsGroup { get; set; }

    public string? Title { get; set; }

    public string? DirectKey { get; set; }

    public Guid CreatedByUserId { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public virtual ICollection<ConversationParticipant> ConversationParticipants { get; set; } = new List<ConversationParticipant>();

    public virtual ApplicationUser CreatedByUser { get; set; } = null!;

    public virtual ICollection<Message> Messages { get; set; } = new List<Message>();
}
