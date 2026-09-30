using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MiniCrm.Application.DTO;
using MiniCrm.Application.Services;
using MiniCrm.Core.Exceptions;
using MiniCrm.Infrastructure.Identity;
namespace MiniCrm.Api.Controllers.Business;

[Route("api/[controller]")]
[ApiController]
// [Authorize(Roles = AppRoles.Business)]
public class BusinessController(IAuthService authService, IBusinessService businessService) : ControllerBase
{
    private readonly IAuthService _authService = authService;
    private readonly IBusinessService _businessService = businessService;
    // GetBusinessInfos

    [HttpGet]
    public async Task<ActionResult<BusinessInfosResult>> GetBusinessInfos()
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
        if (!Guid.TryParse(idClaim, out var userId))
            return Problem(statusCode: StatusCodes.Status401Unauthorized, title: "Invalid token");
        try
        {
            var infos = await _businessService.GetBusinessInfos(userId);
            return Ok(infos);
        }
        catch(ForbiddenException)
        {
            return Problem(statusCode: StatusCodes.Status403Forbidden,title: "Unauthorized", detail: "User not found or inactive.");
        }
        catch(DatabaseException)
        {
            return Problem(statusCode: StatusCodes.Status500InternalServerError,
                title: "internal error", detail: "Error fetching businesses.");
        }
        // return Ok();
    }
}

