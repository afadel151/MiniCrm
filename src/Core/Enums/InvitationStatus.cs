namespace MiniCrm.Core.Enums;

public enum InvitationStatus
{
    Pending = 0,   // the filtered unique index relies on Pending being 0
    Accepted = 1,
    Revoked = 2,
    Expired = 3    // never stored: derived from ExpiresAtUtc when read
}
public enum InviteeAccountState { NoAccount, BusinessAccount, ClientAccount, OtherAccount }
