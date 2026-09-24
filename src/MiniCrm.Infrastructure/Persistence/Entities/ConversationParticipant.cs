using System;
using System.Collections.Generic;
using MiniCrm.Infrastructure.Identity;
namespace MiniCrm.Infrastructure.Persistence.Entities;

public partial class ConversationParticipant
{
    public int ConversationId { get; set; }

    public Guid UserId { get; set; }

    public DateTime JoinedAtUtc { get; set; }

    public long? LastReadMessageId { get; set; }

    public virtual Conversation Conversation { get; set; } = null!;

    public virtual ApplicationUser User { get; set; } = null!;
}
