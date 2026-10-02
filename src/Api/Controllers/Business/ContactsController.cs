
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MiniCrm.Application.DTO;
using MiniCrm.Application.Helpers;
using MiniCrm.Application.Services;
using MiniCrm.Infrastructure.Identity;
namespace MiniCrm.Api.Controllers.Business;

[ApiController]
[Route("api/business/{businessId:int}/contacts")]
[Authorize(Roles = AppRoles.Business)]
public class ContactsController(IContactService svc) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResult<ContactDto>>> List(
        int businessId, [FromQuery] string? q, [FromQuery] int page = 1, [FromQuery] int pageSize = 25, CancellationToken ct = default) =>
        Ok(await svc.ListAsync(User.GetUserId(), businessId, q, page, pageSize, ct));
 
    [HttpGet("{contactId:int}")]
    public async Task<ActionResult<ContactDto>> Get(int businessId, int contactId, CancellationToken ct) =>
        Ok(await svc.GetAsync(User.GetUserId(), businessId, contactId, ct));
 
    [HttpPost]
    public async Task<ActionResult<ContactDto>> Create(int businessId, SaveContactDto dto, CancellationToken ct)
    {
        var r = await svc.CreateAsync(User.GetUserId(), businessId, dto, ct);
        return CreatedAtAction(nameof(Get), new { businessId, contactId = r.Id }, r);
    }
 
    [HttpPut("{contactId:int}")]
    public async Task<ActionResult<ContactDto>> Update(int businessId, int contactId, SaveContactDto dto, CancellationToken ct) =>
        Ok(await svc.UpdateAsync(User.GetUserId(), businessId, contactId, dto, ct));
 
    [HttpDelete("{contactId:int}")]
    public async Task<IActionResult> Delete(int businessId, int contactId, CancellationToken ct)
    {
        await svc.DeleteAsync(User.GetUserId(), businessId, contactId, ct);
        return NoContent();
    }
}