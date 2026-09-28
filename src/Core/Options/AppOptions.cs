using System.ComponentModel.DataAnnotations;

namespace MiniCrm.Core.Options;

public sealed class AppOptions
{
    public const string SectionName = "App";

    [Required(ErrorMessage = "App:TimeZoneId est requis.")]
    public string TimeZoneId { get; set; } = "Africa/Algiers";

    [Required(ErrorMessage = "App:CurrencyCode est requis.")]
    public string CurrencyCode { get; set; } = "DZD";

    [Required(ErrorMessage = "App:DefaultCulture est requis.")]
    public string DefaultCulture { get; set; } = "fr-DZ";
}
