namespace MiniCrm.Infrastructure.Persistence.Entities;

public class SellerRating
{
    public int Id { get; set; }
    public Guid SellerUserId { get; set; }
    public Guid ClientUserId { get; set; }
    public byte Stars { get; set; }
    public string? Comment { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
}