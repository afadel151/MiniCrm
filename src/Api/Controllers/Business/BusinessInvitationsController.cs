using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MiniCrm.Application.DTO;
using MiniCrm.Application.Helpers;
using MiniCrm.Application.Services;
using MiniCrm.Infrastructure.Identity;

namespace MiniCrm.Api.Controllers.Business; // same namespace as your other controllers


[ApiController]
[Route("api/business/{businessId:int}/invitations")]
[Authorize(Roles = AppRoles.Business)]
public class BusinessInvitationsController(IInvitationService svc,ILogger<BusinessInvitationsController> logger) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<InvitationCreatedDto>> Create(int businessId, CreateInvitationDto dto, CancellationToken ct)
    {
        logger.LogInformation("dto : {R}",dto);
        return Ok(await svc.CreateAsync(User.GetUserId(), businessId, dto, ct));

    }
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<InvitationListItemDto>>> List(int businessId, CancellationToken ct) =>
        Ok(await svc.ListAsync(User.GetUserId(), businessId, ct));

    [HttpDelete("{invitationId:int}")]
    public async Task<IActionResult> Revoke(int businessId, int invitationId, CancellationToken ct)
    {
        await svc.RevokeAsync(User.GetUserId(), businessId, invitationId, ct);
        return NoContent();
    }
}
