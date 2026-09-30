using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MiniCrm.Application.DTO;
using MiniCrm.Application.Helpers;
using MiniCrm.Application.Services;

namespace MiniCrm.Api.Controllers.Business; // same namespace as your other controllers

[ApiController]
[Route("api/invitations")]
public class InvitationsController(IInvitationService svc) : ControllerBase
{
    [HttpPost("preview")]
    [AllowAnonymous]
    public async Task<ActionResult<InvitationPreviewDto>> Preview(InvitationTokenRequest request, CancellationToken ct)
    {
        Response.Headers.CacheControl = "no-store";
        return Ok(await svc.PreviewAsync(request.Token, ct));
    }

    [HttpPost("accept")]
    [Authorize]
    public async Task<ActionResult<AcceptInvitationResult>> Accept(InvitationTokenRequest request, CancellationToken ct) =>
        Ok(await svc.AcceptAsync(User.GetUserId(), request.Token, ct));

    // Called only by a Nitro route. The generic /api/backend proxy requires a session, so anonymous users can't reach this through it.
    [HttpPost("register")]
    [AllowAnonymous]
    public async Task<ActionResult<AcceptInvitationResult>> Register(RegisterStaffRequest request, CancellationToken ct) =>
        Ok(await svc.RegisterAndAcceptAsync(request, ct));
}