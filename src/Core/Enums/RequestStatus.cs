namespace MiniCrm.Core.Enums;

public enum RequestStatus : byte
{
    New   = 0,
    Working      = 1,
    WaitingCustomer = 2,
    Escalated = 3,
    Closed =4,
}
