using System.Reflection;
using MiniCrm.Infrastructure.Persistence.Entities;
using MiniCrm.Infrastructure.Persistence.Configurations;

namespace MiniCrm.Infrastructure.Services;

public static class Stamp
{
    public static void Created<T>(T entity, Guid userId, DateTime nowUtc) where T : class
    {
        SetProperty(entity, "CreatedAtUtc", nowUtc);
        SetProperty(entity, "CreatedByUserId", userId);
    }

    public static void Updated<T>(T entity, Guid userId, DateTime nowUtc) where T : class
    {
        SetProperty(entity, "UpdatedAtUtc", nowUtc);
        SetProperty(entity, "UpdatedByUserId", userId);
    }

    public static void Deleted<T>(T entity, Guid userId, DateTime nowUtc) where T : class
    {
        if (entity is ISoftDeletable softDeletable)
        {
            softDeletable.IsDeleted = true;
            softDeletable.DeletedAtUtc = nowUtc;
            SetProperty(entity, "UpdatedByUserId", userId);
            SetProperty(entity, "UpdatedAtUtc", nowUtc);
        }
    }

    private static void SetProperty<T>(T entity, string propertyName, object value)
    {
        PropertyInfo? prop = typeof(T).GetProperty(propertyName, BindingFlags.Public | BindingFlags.Instance);
        if (prop != null && prop.CanWrite)
        {
            prop.SetValue(entity, value);
        }
    }
}
