namespace MiniCrm.Core.Services;

public interface ILocalTime
{
    DateTime ToLocal(DateTime utcDateTime);
    DateTime ToUtc(DateTime localDateTime);
    DateTime GetCurrentLocal();
}
