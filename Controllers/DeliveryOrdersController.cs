using Mammod.Data;
using Mammod.Models;
using Microsoft.AspNetCore.Mvc;

namespace Mammod.Controllers;

/// <summary>
/// รายการนำส่ง — the only paginated list in the API, so the one place the
/// <c>{ items, total, page, pageSize }</c> envelope appears. Filtering, sorting
/// and paging all happen here rather than on the client: the client asks for one
/// page and is told how many there are in total.
/// </summary>
[ApiController]
[Route("delivery-orders")]
public sealed class DeliveryOrdersController(DeliveryOrderStore store) : ControllerBase
{
    [HttpGet]
    public ActionResult<Paginated<DeliveryOrder>> List(
        [FromQuery] string? search,
        [FromQuery] string? status,
        [FromQuery] string? sort,
        [FromQuery] int? page,
        [FromQuery] int? pageSize) =>
        store.List(search, status, sort, page ?? 1, pageSize ?? 10);

    [HttpPost]
    public ActionResult<DeliveryOrder> Create([FromBody] DeliveryOrder input) => store.Create(input);

    [HttpPut("{id}")]
    public ActionResult<DeliveryOrder> Update(string id, [FromBody] DeliveryOrder input) =>
        store.Update(id, input);

    [HttpDelete("{id}")]
    public IActionResult Remove(string id)
    {
        store.Remove(id);
        return NoContent();
    }
}

/// <summary>Item master, read-only from the transport side.</summary>
[ApiController]
[Route("skus")]
public sealed class SkusController : ControllerBase
{
    private static readonly object[] Skus =
    [
        new { sku = "WMS-RM-110", description = "PP Resin Pellets", uom = "KG", packKey = "PALLET", lotControlled = true },
        new { sku = "WMS-RM-115", description = "PE Film Roll 1.2m", uom = "ROLL", packKey = "CASE", lotControlled = true },
        new { sku = "WMS-PK-201", description = "กล่องลูกฟูก 3 ชั้น 60x40x40", uom = "EA", packKey = "CASE", lotControlled = false },
        new { sku = "WMS-PK-205", description = "เทปปิดกล่อง OPP 48mm", uom = "EA", packKey = "CASE", lotControlled = false },
        new { sku = "WMS-FG-301", description = "ผงซักฟอก 3kg", uom = "EA", packKey = "CASE", lotControlled = true },
        new { sku = "WMS-FG-310", description = "นมยูเอชที 1L", uom = "EA", packKey = "CASE", lotControlled = true },
        new { sku = "WMS-SP-402", description = "พาเลทไม้ 100x120", uom = "EA", packKey = "EACH", lotControlled = false },
    ];

    [HttpGet]
    public ActionResult<object[]> List() => Skus;
}
