using Microsoft.AspNetCore.Identity;
using MiniCrm.Infrastructure.Persistence.Entities;

namespace MiniCrm.Infrastructure.Identity;

public sealed class ApplicationUser : IdentityUser<Guid>
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
    public bool MustChangePassword { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? LastLoginAtUtc { get; set; }


    public ICollection<BusinessMembership> BusinessMemberships {get;set;} = []; //
    public ICollection<Company> CreatedCompanies {get;set;} = [];
    public ICollection<Contact> CreatedContacts {get;set;} = [];
    public ICollection<Conversation> ConversationCreations {get;set;} = [];
    public ICollection<ConversationParticipant> ConversationParticipations {get;set;} = [];
    public ICollection<Interaction> Interactions {get;set;} = [];
    public ICollection<Message> Messages {get;set;} = [];
    public ICollection<Opportunity> Opportunities {get;set;} = [];
    public ICollection<Reminder> Reminders {get;set;} = [];
    public ICollection<Request> Requests {get;set;} = [];
    public ICollection<ClientRating> ClientRatings {get;set;} = [];
    public ICollection<ClientRating> RatingsDone {get;set;} = [];
    
}
