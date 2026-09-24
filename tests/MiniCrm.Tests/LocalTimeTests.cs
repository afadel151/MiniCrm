using System;
using Microsoft.Extensions.Options;
using MiniCrm.Core.Options;
using MiniCrm.Infrastructure.Services;
using Shouldly;
using Xunit;

namespace MiniCrm.Tests;

public class TestTimeProvider : TimeProvider
{
    private DateTimeOffset _utcNow;

    public TestTimeProvider(DateTimeOffset utcNow)
    {
        _utcNow = utcNow;
    }

    public override DateTimeOffset GetUtcNow() => _utcNow;

    public void SetUtcNow(DateTimeOffset utcNow)
    {
        _utcNow = utcNow;
    }
}

public class LocalTimeTests
{
    [Fact]
    public void LocalTime_Converts_Utc_To_Configured_TimeZone()
    {
        var fakeClock = new TestTimeProvider(new DateTimeOffset(2026, 9, 21, 12, 0, 0, TimeSpan.Zero));

        var options = Options.Create(new AppOptions
        {
            TimeZoneId = "Africa/Algiers",
            CurrencyCode = "DZD",
            DefaultCulture = "fr-DZ"
        });

        var localTime = new LocalTime(fakeClock, options);
        var currentLocal = localTime.GetCurrentLocal();

        currentLocal.ShouldBe(new DateTime(2026, 9, 21, 13, 0, 0)); // UTC+1
    }
}
