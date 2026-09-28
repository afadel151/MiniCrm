namespace MiniCrm.Infrastructure.Identity;

public static class AppRoles
{
    public const string Admin = "Admin";
    public const string BusinessManager = "BusinessManager";
    public const string BusinessStaff = "BusinessStaff";
    public const string Client = "Client";
    public static readonly string[] All = [Admin, BusinessManager,BusinessStaff,Client];
    public static readonly string[] Staff = [BusinessManager, BusinessStaff];
}

public static class AppPolicies
{
    public const string AdminOnly = "AdminOnly";
    public const string BusinessOnly= "BusinessOnly";
    public const string BusinessManagerOnly= "BusinessManagerOnly";
    public const string ClientOnly= "ClientOnly";
    
}

public static class AppClaims
{
    public const string MustChangePassword = "must_change_password";
    public const string TenantId = "tenant_id";
}
