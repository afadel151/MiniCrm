namespace MiniCrm.Core.Enums;

public enum BusinessMemberRole : byte
{
    Manager = 1,   // old "Admin" — full CRM access within the tenant
    Staff = 2,     // old "User" — limited CRM access within the tenant
}