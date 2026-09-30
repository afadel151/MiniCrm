namespace MiniCrm.Infrastructure.Identity;

public static class AppRoles
{
    public const string Admin = "Admin";
    public const string Business = "Business";
    public const string Client = "Client";
    public static readonly string[] All = [Admin, Business,Client];
}

public static class AppPolicies
{
    public const string AdminOnly = "AdminOnly";
    public const string BusinessOnly= "BusinessOnly";
    public const string ClientOnly= "ClientOnly";
    
}

public static class AppClaims
{
    public const string MustChangePassword = "must_change_password";
    public const string TenantId = "tenant_id";
}
