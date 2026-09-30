using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MiniCrm.Application.DTO;
using MiniCrm.Application.Services;
using MiniCrm.Core.Exceptions;
namespace MiniCrm.Api.Controllers.Business;

[Route("api/business/[controller]")]
[ApiController]

public class TeamController(IAuthService authService) : ControllerBase
{
    private readonly IAuthService _authService = authService;

    [HttpPost("/invite")]
    public async Task<ActionResult> InviteStaffMember()
    {
        return Ok();
    }
}

