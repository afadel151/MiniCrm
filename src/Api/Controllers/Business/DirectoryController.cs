
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MiniCrm.Application.DTO;
using MiniCrm.Application.Helpers;
using MiniCrm.Application.Services;
using MiniCrm.Core.Enums;
namespace MiniCrm.Api.Controllers.Business;


[ApiController]
[Route("api/directory")]
[Authorize]
public class DirectoryController(IDirectoryService svc) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResult<PublicBusinessDto>>> Search(
        [FromQuery] string? q, [FromQuery] BusinessDomain? domain,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        Ok(await svc.SearchAsync(q, domain, page, pageSize, ct));
 
    [HttpGet("{businessId:int}")]
    public async Task<ActionResult<PublicBusinessDto>> Get(int businessId, CancellationToken ct) =>
        Ok(await svc.GetAsync(businessId, ct));
 
    [HttpGet("{businessId:int}/ratings")]
    public async Task<ActionResult<PagedResult<RatingView>>> Ratings(
        int businessId, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        Ok(await svc.ListRatingsAsync(businessId, page, pageSize, ct));
 
    [HttpPut("{businessId:int}/rating")]
    [Authorize(Roles = "Client")]
    public async Task<ActionResult<RatingView>> Rate(int businessId, RatingDto dto, CancellationToken ct) =>
        Ok(await svc.RateAsync(User.GetUserId(), businessId, dto, ct));
 
    [HttpDelete("{businessId:int}/rating")]
    [Authorize(Roles = "Client")]
    public async Task<IActionResult> DeleteRating(int businessId, CancellationToken ct)
    {
        await svc.DeleteRatingAsync(User.GetUserId(), businessId, ct);
        return NoContent();
    }
}