namespace MiniCrm.Core.Exceptions;

public class UnauthenticatedException : Exception
{
    public UnauthenticatedException(string message = "Utilisateur non authentifié.") : base(message)
    {
    }
}
