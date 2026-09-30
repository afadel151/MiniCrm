using System.Security.Claims;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using MiniCrm.Application.Services;

namespace MiniCrm.Application.Helpers;
public sealed class DomainExceptionHandler(IProblemDetailsService problems) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        if (exception is not DomainException d) return false;

        httpContext.Response.StatusCode = d.Status;
        return await problems.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            ProblemDetails = new ProblemDetails { Status = d.Status, Title = d.Title, Detail = d.Message }
        });
    }
}


public static class UserExtensions
{
    public static Guid GetUserId(this ClaimsPrincipal u)
    {
        var v = u.FindFirstValue(ClaimTypes.NameIdentifier) ?? u.FindFirstValue("sub");
        return Guid.TryParse(v, out var id) ? id : throw new ForbiddenDomainException("Invalid session.");
    }
}