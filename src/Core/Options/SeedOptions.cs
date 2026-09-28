using System.ComponentModel.DataAnnotations;

namespace MiniCrm.Core.Options;

public sealed class SeedOptions
{
    public const string SectionName = "Seed";

    [EmailAddress(ErrorMessage = "Seed:AdminEmail doit être une adresse e-mail valide.")]
    public string AdminEmail { get; set; } = string.Empty;

    public string AdminPassword { get; set; } = string.Empty;
}
