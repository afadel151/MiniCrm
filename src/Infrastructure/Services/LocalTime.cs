using Microsoft.Extensions.Options;
using MiniCrm.Core.Options;
using MiniCrm.Core.Services;

namespace MiniCrm.Infrastructure.Services;

public sealed class LocalTime : ILocalTime
{
    private readonly TimeProvider _clock;
    private readonly TimeZoneInfo _timeZone;

    public LocalTime(TimeProvider clock, IOptions<AppOptions> options)
    {
        _clock = clock;
        string tzId = options.Value.TimeZoneId;
        try
        {
            _timeZone = TimeZoneInfo.FindSystemTimeZoneById(tzId);
        }
        catch (TimeZoneNotFoundException)
        {
            // Fallback for cross-platform matching (e.g. Windows vs Linux timezone IDs)
            _timeZone = TimeZoneInfo.Utc;
        }
    }

    public DateTime ToLocal(DateTime utcDateTime)
    {
        var utc = DateTime.SpecifyKind(utcDateTime, DateTimeKind.Utc);
        return TimeZoneInfo.ConvertTimeFromUtc(utc, _timeZone);
    }

    public DateTime ToUtc(DateTime localDateTime)
    {
        var unspecified = DateTime.SpecifyKind(localDateTime, DateTimeKind.Unspecified);
        return TimeZoneInfo.ConvertTimeToUtc(unspecified, _timeZone);
    }

    public DateTime GetCurrentLocal()
    {
        return ToLocal(_clock.GetUtcNow().UtcDateTime);
    }
}
