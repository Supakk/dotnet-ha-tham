using Mammod.Data;
using Mammod.Database.Documents;
using Mammod.Dtos;
using Mammod.Models;
using Microsoft.AspNetCore.Mvc;

namespace Mammod.Controllers;

/// <summary>
/// ใบปิดบรรทุก — the core of TMS.
///
/// The write side mirrors the flow instead of one bare update: each step is a
/// transition the store validates. Every action here is one row of the "ปลายทาง
/// API ของแต่ละก้าว" table in <c>docs/tms-sequence.md</c> on the client side.
///
/// The controller itself does nothing but unpack the request and hand it to
/// <see cref="TmsStore"/> — the rules live there, in one place, so there is no
/// second copy of them to drift.
/// </summary>
[ApiController]
[Route("manifests")]
public sealed class ManifestsController(TmsStore store, DocumentReadQueries? reads = null) : ControllerBase
{
    /// <summary>
    /// Reads come from SQL, scoped to the warehouse the request named.
    ///
    /// <paramref name="reads"/> is only registered when a database is
    /// configured, so a plain <c>dotnet run</c> with no connection string still
    /// works off the seed — that is the whole reason the parameter is optional.
    /// With a database it is always present, and the store is not consulted:
    /// two sources answering the same question is how they start disagreeing.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<Manifest>>> List(CancellationToken ct) =>
        reads is null ? store.ListManifests() : await reads.ManifestsAsync(ct);

    /// <summary>
    /// One manifest by its number.
    ///
    /// A document belonging to another warehouse answers 404, not 403: saying
    /// "forbidden" would confirm the number exists somewhere, which is itself
    /// something the caller is not entitled to know.
    /// </summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<Manifest>> Detail(string id, CancellationToken ct)
    {
        if (reads is null)
        {
            var seeded = store.ListManifests().FirstOrDefault(m => m.Id == id || m.ManifestNo == id);
            return seeded is null ? NotFound() : seeded;
        }

        var manifest = await reads.ManifestAsync(id, ct);
        return manifest is null ? NotFound() : manifest;
    }

    /// <summary>
    /// Delivery orders waiting to be loaded onto a truck.
    ///
    /// Routed above <c>{id}</c> would be ambiguous either way — ASP.NET Core
    /// prefers the literal segment over the parameter, so "pending-stops" is
    /// never read as a manifest id.
    /// </summary>
    [HttpGet("pending-stops")]
    public async Task<ActionResult<List<ManifestStop>>> PendingStops(
        [FromServices] IDeliveryOrderQuery? pool, CancellationToken ct)
    {
        if (pool is null) return store.ListPendingStops();

        // The pool is derived, not stored: the delivery orders that no live plan
        // and no live shipment has claimed. Shaped here into the stop the client
        // already draws, so the screen does not have to learn a second type for
        // "an order that is not on anything yet".
        var available = await pool.GetAvailableAsync(ct);
        return available.Select(o => new ManifestStop
        {
            Id = o.OrderKey,
            DoNo = o.OrderKey,
            SoNo = "",
            PickNo = "",
            PickDate = "",
            WarehouseCode = o.WhseId,
            DeliveryZoneId = o.Zone is null ? "" : $"zone-{o.Zone}",
            Customer = o.CompanyName ?? "",
            Address = o.ShipTo,
            DueDate = o.DeliveryDate?.ToString("yyyy-MM-dd") ?? "",
            Position = [],
        }).ToList();
    }

    [HttpPost]
    public ActionResult<Manifest> Create([FromBody] ManifestInput input) =>
        store.CreateManifest(input);

    /// <summary>Edit: vehicle, driver, route, dock, cost — and which stops ride.</summary>
    [HttpPut("{id}")]
    public ActionResult<Manifest> Update(string id, [FromBody] ManifestInput input) =>
        store.UpdateManifest(id, input);

    /// <summary>Draft → confirmed. The document is now final on the TMS side.</summary>
    [HttpPost("{id}/confirm")]
    public ActionResult<Manifest> Confirm(string id) => store.ConfirmManifest(id);

    /// <summary>Confirmed → sent. Hands the load to MMX and locks the document.</summary>
    [HttpPost("{id}/send")]
    public ActionResult<Manifest> Send(string id) => store.SendManifest(id);

    /// <summary>Cancels and returns the stops to the pending pool.</summary>
    [HttpPost("{id}/cancel")]
    public ActionResult<Manifest> Cancel(string id, [FromBody] CancelRequest? body) =>
        store.CancelManifest(id, body?.Reason ?? "");

    /// <summary>
    /// Removes a cancelled document outright. Cancel first: that is what returns
    /// the load and records the reason, and a plan that issued this one goes back
    /// to being a draft rather than pointing at a number that is gone.
    /// </summary>
    [HttpDelete("{id}")]
    public IActionResult Delete(string id) { store.DeleteManifest(id); return NoContent(); }

    [HttpPost("{id}/express")]
    public ActionResult<Manifest> Express(string id, [FromBody] ExpressDispatch express) =>
        store.MarkExpress(id, express);

    /// <summary>
    /// Records the invoice against a ใบปิดบรรทุก. The first mutation served from
    /// SQL rather than from <see cref="TmsStore"/>.
    ///
    /// <b>If-Match is required.</b> The value is the <c>currentVersion</c> the
    /// client got when it read the document — SQL Server's ROWVER, base64. Sent
    /// as a header rather than in the body because it is a precondition on the
    /// request, not part of what is being written, and because there is no body
    /// here to put it in: invoicing takes no input at all.
    ///
    /// The controller does none of the work. It unpacks the header, calls the
    /// service, and reads the document back through the same projection every
    /// other endpoint uses so the response is the shape the client already
    /// knows — now carrying the <b>new</b> version, which is what the next
    /// mutation has to send.
    ///
    /// The store branch is the no-database mode, the same one the reads above
    /// have. It is not a second write: with a database configured the store is
    /// never touched here, and without one there is no SQL row to invoice.
    /// Writing both would leave two accounts of whether the document was billed.
    /// </summary>
    [HttpPost("{id}/invoice")]
    public async Task<ActionResult<Manifest>> Invoice(
        string id,
        [FromServices] IShipmentService? shipments,
        CancellationToken ct)
    {
        if (shipments is null || reads is null) return store.MarkInvoiced(id);

        // Passed through as sent — quoting, W/ prefixes and all. Reading it is
        // DocumentIdentity's job, and a second parser here would be a second
        // opinion on what counts as a version.
        var ifMatch = Request.Headers.IfMatch.ToString();

        await shipments.MarkInvoicedAsync(id, ifMatch, ct);

        // Read back rather than mapped from the row the service returned: the
        // client's Manifest is assembled from four tables, and only this
        // projection knows how. The commit has happened, so the version it reads
        // is the one SQL Server just stamped.
        var manifest = await reads.ManifestAsync(id, ct);
        return manifest is null ? NotFound() : manifest;
    }

    /// <summary>Splits the stops onto MN-…-1, -2, … Returns both documents, parent first.</summary>
    [HttpPost("{id}/split")]
    public ActionResult<Manifest[]> Split(string id, [FromBody] SplitRequest body) =>
        store.SplitManifest(id, body?.StopIds ?? []);

    /// <summary>Moves stops between two drafts. Returns source then target.</summary>
    [HttpPost("{id}/move")]
    public ActionResult<Manifest[]> Move(string id, [FromBody] MoveRequest body)
    {
        if (string.IsNullOrWhiteSpace(body?.ToId))
            throw new DomainException("ต้องระบุใบปลายทาง");
        return store.MoveStops(id, body.ToId, body.StopIds ?? []);
    }

    /// <summary>
    /// What OMS reports back. Stands in for the inbound webhook until it exists —
    /// `เสร็จสิ้น` and `ตีกลับ` are not states TMS may set on its own.
    /// </summary>
    [HttpPost("{id}/status")]
    public ActionResult<Manifest> Status(string id, [FromBody] ExternalStatusRequest body) =>
        store.ApplyExternalStatus(id, body?.Outcome ?? "", body?.Message ?? "");
}
