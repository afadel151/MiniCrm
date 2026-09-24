namespace MiniCrm.Core.Exceptions;

public class ForbiddenException : Exception
{
    public ForbiddenException(string message = "Accès non autorisé.") : base(message)
    {
    }
}
