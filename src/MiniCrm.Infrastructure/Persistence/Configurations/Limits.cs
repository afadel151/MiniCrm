namespace MiniCrm.Infrastructure.Persistence.Configurations;

public static class Limits
{
    public const int AuditAction = 50;
    public const int AuditEntityName = 100;
    public const int AuditEntityId = 50;
    public const int AuditIpAddress = 45;

    public const int CompanyName = 200;
    public const int CompanyWebsite = 255;

    public const int ContactFirstName = 100;
    public const int ContactLastName = 100;
    public const int ContactEmail = 256;
    public const int ContactPhone = 30;
    public const int ContactAddress = 200;
    public const int ContactCity = 100;
    public const int ContactPostalCode = 20;
    public const int ContactCountry = 100;

    public const int ConversationTitle = 200;
    public const int ConversationDirectKey = 80;

    public const int InteractionSubject = 200;
    public const int InteractionNotes = 4000;

    public const int MessageBody = 4000;

    public const int OpportunityTitle = 200;
    public const int OpportunityLostReason = 500;
    public const int OpportunityDescription = 2000;

    public const int StageName = 100;

    public const int RefreshTokenHash = 64;
    public const int RefreshTokenCreatedByIp = 45;
    public const int RefreshTokenRevokedReason = 100;

    public const int ReminderTitle = 200;
    public const int ReminderNotes = 2000;
}
