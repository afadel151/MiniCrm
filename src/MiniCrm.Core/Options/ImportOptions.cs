using System.ComponentModel.DataAnnotations;

namespace MiniCrm.Core.Options;

public sealed class ImportOptions
{
    public const string SectionName = "Import";

    [Range(1024, 50 * 1024 * 1024)]
    public long MaxBytes { get; set; } = 5 * 1024 * 1024; // 5 MB

    [Range(1, 100000)]
    public int MaxRows { get; set; } = 10000;
}
