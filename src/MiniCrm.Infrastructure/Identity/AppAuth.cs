namespace MiniCrm.Infrastructure.Identity;

public static class AppRoles
{
    public const string Admin = "Admin";
    public const string User = "User";
    public const string Client = "Client";
    public static readonly string[] All = [Admin, User,Client];
    public static readonly string[] Staff = [Admin, User];
}

public static class AppPolicies
{
    public const string AdminOnly = "AdminOnly";
    public const string StaffOnly= "StaffOnly";
    
}

public static class AppClaims
{
    public const string MustChangePassword = "must_change_password";
}
