namespace MiniCrm.Core.Enums;

public enum RequestOrigin : byte
{
    Message   = 0,
    Email      = 1,
    phone = 2,
    Web = 3,
    Meeting=4,
    Other = 99
}
