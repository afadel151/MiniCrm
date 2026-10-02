using MiniCrm.Core.Enums;

namespace MiniCrm.Application.Helpers;

public static class PermsHelper
{
    public static bool CanEditBusiness(BusinessMemberRole r) =>
        r is  BusinessMemberRole.Manager;

    public static bool CanDeleteContact(BusinessMemberRole r) =>
        r is  BusinessMemberRole.Manager;

    /// <summary>Owners manage anyone except the primary owner (checked by callers). Managers manage Staff only.</summary>
    public static bool CanManage(BusinessMemberRole actor, BusinessMemberRole target) => actor switch
    {
        BusinessMemberRole.Manager => target == BusinessMemberRole.Staff,
        _ => false
    };
}
