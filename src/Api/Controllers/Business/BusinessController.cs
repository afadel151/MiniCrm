using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using MiniCrm.Application.DTO;
using MiniCrm.Application.Helpers;
using MiniCrm.Application.Services;
using MiniCrm.Core.Exceptions;
using MiniCrm.Infrastructure.Identity;
namespace MiniCrm.Api.Controllers.Business;

[Route("api/[controller]")]
[ApiController]
// [Authorize(Roles = AppRoles.Business)]
public class BusinessController(IBusinessService businessService) : ControllerBase
{
    private readonly IBusinessService _businessService = businessService;

    [HttpGet]
    public async Task<ActionResult<BusinessInfosResult>> ListMine(CancellationToken ct) =>
            Ok(await _businessService.ListMineAsync(User.GetUserId(), ct));

    [HttpPost]
    public async Task<ActionResult<BusinessDetail>> Create(CreateBusinessDto dto, CancellationToken ct)
    {
        var r = await _businessService.CreateAsync(User.GetUserId(), dto, ct);
        return CreatedAtAction(nameof(Get), new { businessId = r.Id }, r);
    }

    [HttpGet("{businessId:int}")]
    public async Task<ActionResult<BusinessDetail>> Get(int businessId, CancellationToken ct) =>
        Ok(await _businessService.GetAsync(User.GetUserId(), businessId, ct));

    [HttpPut("{businessId:int}")]
    public async Task<ActionResult<BusinessDetail>> Update(int businessId, UpdateBusinessDto dto, CancellationToken ct) =>
        Ok(await _businessService.UpdateAsync(User.GetUserId(), businessId, dto, ct));

    [HttpDelete("{businessId:int}")]
    public async Task<IActionResult> Delete(int businessId, CancellationToken ct)
    {
        await _businessService.DeleteAsync(User.GetUserId(), businessId, ct);
        return NoContent();
    }

    [HttpGet("{businessId:int}/members")]
    public async Task<ActionResult<IReadOnlyList<MemberDto>>> Members(int businessId, CancellationToken ct) =>
        Ok(await _businessService.ListMembersAsync(User.GetUserId(), businessId, ct));

    // [HttpPost("{businessId:int}/members")]
    // public async Task<ActionResult<MemberDto>> AddMember(int businessId, AddMemberDto dto, CancellationToken ct) =>
    //     Ok(await _businessService.AddMemberAsync(User.GetUserId(), businessId, dto, ct));

    [HttpPut("{businessId:int}/members/{membershipId:int}/role")]
    public async Task<IActionResult> ChangeRole(int businessId, int membershipId, ChangeMemberRoleDto dto, CancellationToken ct)
    {
        await _businessService.ChangeMemberRoleAsync(User.GetUserId(), businessId, membershipId, dto, ct);
        return NoContent();
    }

    [HttpDelete("{businessId:int}/members/{membershipId:int}")]
    public async Task<IActionResult> RemoveMember(int businessId, int membershipId, CancellationToken ct)
    {
        await _businessService.RemoveMemberAsync(User.GetUserId(), businessId, membershipId, ct);
        return NoContent();
    }
}


