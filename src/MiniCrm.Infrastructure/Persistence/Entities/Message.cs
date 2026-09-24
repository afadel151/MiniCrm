using System;
using System.Collections.Generic;
using MiniCrm.Infrastructure.Identity;
namespace MiniCrm.Infrastructure.Persistence.Entities;

public partial class Message
{
    public long Id { get; set; }

    public int ConversationId { get; set; }

    public Guid SenderUserId { get; set; }

    public string Body { get; set; } = null!;

    public DateTime SentAtUtc { get; set; }

    public DateTime? EditedAtUtc { get; set; }

    public bool IsDeleted { get; set; }

    public virtual Conversation Conversation { get; set; } = null!;

    public virtual ApplicationUser SenderUser { get; set; } = null!;
}
