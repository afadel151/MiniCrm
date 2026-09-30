using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MiniCrm.Application.DTO;
using MiniCrm.Application.Helpers;
using MiniCrm.Application.Services;

namespace MiniCrm.Api.Controllers.Business; // same namespace as your other controllers

// ---------- Staff side: only Manager-level members of that business ----------

[ApiController]
[Route("api/businesses/{businessId:int}/invitations")]
[Authorize(Roles = "Business")]
public class BusinessInvitationsController(IInvitationService svc) : ControllerBase
{
    // Also the "resend" action: inviting the same email again replaces the previous pending link.
    [HttpPost]
    public async Task<ActionResult<InvitationCreatedDto>> Create(int businessId, CreateInvitationDto dto, CancellationToken ct) =>
        Ok(await svc.CreateAsync(User.GetUserId(), businessId, dto, ct));

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
