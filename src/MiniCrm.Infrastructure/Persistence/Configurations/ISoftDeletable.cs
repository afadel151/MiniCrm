namespace MiniCrm.Infrastructure.Persistence.Configurations;

public interface ISoftDeletable
{
    bool IsDeleted { get; set; }
    DateTime DeletedAtUtc {get;set;}
}