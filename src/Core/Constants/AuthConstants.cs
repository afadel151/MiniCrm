namespace MiniCrm.Core.Constants;

public static class AuthConstants
{
    public const string SmartScheme = "smart";
    public const string RefreshTokenCookieName = "refreshToken";

    public static class Policies
    {
        public const string ManageEvents = nameof(ManageEvents);
        public const string ManageInventory = nameof(ManageInventory);
        public const string ManageMembers = nameof(ManageMembers);
        public const string ManageUsers = nameof(ManageUsers);
    }

    public static class Roles
    {
        public const string SuperAdmin = nameof(SuperAdmin);
        public const string Admin = nameof(Admin);
        public const string BoardMember = nameof(BoardMember);
        public const string EventManager = nameof(EventManager);
        public const string InventoryManager = nameof(InventoryManager);
        public const string Member = nameof(Member);
        public const string Guest = nameof(Guest);
        public const string ServiceAccount = nameof(ServiceAccount);
    }
}
