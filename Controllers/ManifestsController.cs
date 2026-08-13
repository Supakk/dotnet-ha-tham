using Mammod.Data;
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
public sealed class ManifestsController(TmsStore store) : ControllerBase
{
    [HttpGet]
    public ActionResult<List<Manifest>> List() => store.ListManifests();

    /// <summary>
    /// Delivery orders waiting to be loaded onto a truck.
    ///
    /// Routed above <c>{id}</c> would be ambiguous either way — ASP.NET Core
    /// prefers the literal segment over the parameter, so "pending-stops" is
    /// never read as a manifest id.
    /// </summary>
    [HttpGet("pending-stops")]
    public ActionResult<List<ManifestStop>> PendingStops() => store.ListPendingStops();

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

    [HttpPost("{id}/express")]
    public ActionResult<Manifest> Express(string id, [FromBody] ExpressDispatch express) =>
        store.MarkExpress(id, express);

    [HttpPost("{id}/invoice")]
    public ActionResult<Manifest> Invoice(string id) => store.MarkInvoiced(id);

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
