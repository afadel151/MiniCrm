namespace MiniCrm.Core.Exceptions;

public sealed class IdentityException : Exception
{
    public IdentityException(string message) : base(message) { }
    public IdentityException(string message, Exception inner) : base(message, inner) { }
}