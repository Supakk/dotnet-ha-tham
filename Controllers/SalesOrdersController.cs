using Mammod.Data;
using Mammod.Database;
using Mammod.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Mammod.Controllers;

/// <summary>
/// Sales orders, read from <c>MMDEV</c>.
///
/// This is the one endpoint with no in-memory fallback, and that is on purpose:
/// sales orders only exist as a table. There was never a fixture for them
/// because there was never a sales-order layer — the number lived in a text
/// column on the delivery order and nothing could be asked of it. Serving this
/// from a fixture would recreate exactly the fiction the split was made to end.
///
/// Reads only. Sales orders arrive from OMS; TMS does not author them.
/// </summary>
[ApiController]
[Route("sales-orders")]
public sealed class SalesOrdersController(IServiceProvider services) : ControllerBase
{
    private AppDbContext? Db() => services.GetService<AppDbContext>();

    private static DomainException NoDatabase() => new(
        "endpoint นี้ต้องต่อฐานข้อมูล — ตั้ง ConnectionStrings:Mmdev แล้วสร้างฐานด้วย " +
        "docs/data-model/build-local-db.ps1",
        StatusCodes.Status503ServiceUnavailable);

    /// <summary>
    /// Newest first, optionally filtered by status or customer.
    /// </summary>
    /// <param name="status">NEW · PARTIAL · CLOSED · CANCELLED</param>
    /// <param name="customerId">The client's prefixed id, e.g. <c>cus-CUS-0001</c>, or the bare key.</param>
    [HttpGet]
    public ActionResult<List<SalesOrder>> List(
        [FromQuery] string? status, [FromQuery] string? customerId, [FromQuery] int limit = 100)
    {
        var db = Db() ?? throw NoDatabase();

        var query = db.SalesOrders.AsQueryable();
        if (!string.IsNullOrWhiteSpace(status))
            query = query.Where(s => s.Status == status.ToUpperInvariant());
        if (!string.IsNullOrWhiteSpace(customerId))
        {
            var key = StripPrefix(customerId);
            query = query.Where(s => s.CustomerKey == key);
        }

        var headers = query
            .OrderByDescending(s => s.OrderDate)
            .Take(Math.Clamp(limit, 1, 1000))
            .ToList();

        return Assemble(db, headers);
    }

    /// <summary>One order with its lines and the deliveries raised against it.</summary>
    [HttpGet("{soNo}")]
    public ActionResult<SalesOrder> Get(string soNo)
    {
        var db = Db() ?? throw NoDatabase();

        var header = db.SalesOrders.FirstOrDefault(s => s.SoKey == soNo)
            ?? throw new DomainException($"ไม่พบใบสั่งขาย {soNo}", StatusCodes.Status404NotFound);

        return Assemble(db, [header]).Single();
    }

    /// <summary>
    /// The delivery orders raised against one sales order — the answer to
    /// "was this shipped in one go or several".
    /// </summary>
    [HttpGet("{soNo}/delivery-orders")]
    public ActionResult<List<DeliveryOrderSummary>> Deliveries(string soNo)
    {
        var db = Db() ?? throw NoDatabase();

        if (!db.SalesOrders.Any(s => s.SoKey == soNo))
            throw new DomainException($"ไม่พบใบสั่งขาย {soNo}", StatusCodes.Status404NotFound);

        return db.DeliveryOrders
            .Where(d => d.SoKey == soNo)
            .OrderBy(d => d.OrderKey)
            .ToList()
            .Select(d => new DeliveryOrderSummary
            {
                DoNo = d.OrderKey,
                SoNo = d.SoKey,
                WarehouseCode = d.WhseId,
                CustomerName = d.CompanyName ?? "",
                DeliveryDate = d.DeliveryDate?.ToString("yyyy-MM-dd"),
                Route = d.Route ?? "",
                Zone = d.Zone ?? "",
                Status = d.Status,
            })
            .ToList();
    }

    /// <summary>
    /// Lines and delivery numbers are fetched for the whole page at once rather
    /// than per order — the alternative issues two queries per row, which is
    /// unnoticeable at ten orders and ruinous at a thousand.
    /// </summary>
    private static List<SalesOrder> Assemble(AppDbContext db, List<SalesOrderRow> headers)
    {
        var keys = headers.Select(h => h.SoKey).ToList();

        var lines = db.SalesOrderLines
            .Where(l => keys.Contains(l.SoKey))
            .OrderBy(l => l.LineNumber)
            .ToList()
            .GroupBy(l => l.SoKey)
            .ToDictionary(g => g.Key, g => g.ToList());

        var deliveries = db.DeliveryOrders
            .Where(d => keys.Contains(d.SoKey))
            .OrderBy(d => d.OrderKey)
            .ToList()
            .GroupBy(d => d.SoKey)
            .ToDictionary(g => g.Key, g => g.Select(d => d.OrderKey).ToList());

        var customers = db.Customers.ToList().ToDictionary(c => c.CustomerKey, c => c.Name);

        return headers.Select(h => new SalesOrder
        {
            SoNo = h.SoKey,
            WarehouseCode = h.WhseId,
            CustomerId = h.CustomerKey is null ? "" : $"cus-{h.CustomerKey}",
            CustomerName = h.CustomerKey is null ? "" : customers.GetValueOrDefault(h.CustomerKey, ""),
            OrderDate = h.OrderDate.ToString("yyyy-MM-ddTHH:mm:ss"),
            RequestedDate = h.RequestedDate?.ToString("yyyy-MM-dd"),
            Source = h.SourceSystem,
            Status = h.Status,
            TotalAmount = h.TotalAmount ?? 0,
            Currency = h.Currency ?? "THB",
            Lines = lines.GetValueOrDefault(h.SoKey, [])
                .Select(l => new SalesOrderLine
                {
                    LineNo = l.LineNumber,
                    Sku = l.Sku,
                    Uom = l.Uom ?? "",
                    OrderQty = l.OrderQty,
                    ShippedQty = l.ShippedQty,
                    UnitPrice = l.UnitPrice ?? 0,
                    ExtendedPrice = l.ExtendedPrice ?? 0,
                    Status = l.Status,
                })
                .ToList(),
            DeliveryOrderNos = deliveries.GetValueOrDefault(h.SoKey, []),
        }).ToList();
    }

    /// <summary>
    /// The client prefixes ids (<c>cus-CUS-0001</c>) to keep them distinct across
    /// entity types; the database stores the bare key. Accepts either, so a value
    /// copied from a response works as a filter without editing.
    /// </summary>
    private static string StripPrefix(string id) =>
        id.StartsWith("cus-", StringComparison.OrdinalIgnoreCase) ? id[4..] : id;
}
