using System.Globalization;
using Mammod.Data;
using Mammod.Database.Documents;
using Mammod.Dtos;
using Mammod.Models;
using Microsoft.AspNetCore.Mvc;

namespace Mammod.Controllers;

/// <summary>
/// แผนขนส่ง — the basket a manifest is issued from.
///
/// A plan answers *what goes out together*; it deliberately carries no truck,
/// driver or seal. The dispatcher answers *on what* by editing the manifest that
/// gets cut from it.
/// </summary>
[ApiController]
[Route("transport-plans")]
public sealed class TransportPlansController(
    TmsStore store, DocumentReadQueries? reads = null) : ControllerBase
{
    /// <summary>
    /// Reads come from SQL, scoped to the warehouse the request named. The store
    /// answers only when no database is configured — see the note on
    /// <c>ManifestsController.List</c>.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<TransportPlan>>> List(CancellationToken ct) =>
        reads is null ? store.ListPlans() : await reads.PlansAsync(ct);

    /// <summary>A plan from another warehouse answers 404, not 403.</summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<TransportPlan>> Detail(string id, CancellationToken ct)
    {
        if (reads is null)
        {
            var seeded = store.ListPlans().FirstOrDefault(p => p.Id == id || p.PlanNo == id);
            return seeded is null ? NotFound() : seeded;
        }

        var plan = await reads.PlanAsync(id, ct);
        return plan is null ? NotFound() : plan;
    }

    /// <summary>
    /// Raises a draft plan, numbered from the global counter.
    ///
    /// The plan is a header only — a delivery date and a route. What it will
    /// carry arrives through <c>PUT {id}/stops</c>, because an order can sit on
    /// one live plan at a time and deciding that is its own transaction.
    ///
    /// <b>The warehouse in the body is ignored.</b> It comes from
    /// <c>X-Warehouse-Id</c> by way of the request context, and nowhere else: a
    /// document filed against a site the caller merely claimed is exactly the
    /// hole the header exists to close. The field stays on the DTO because the
    /// no-database path still reads it.
    ///
    /// The store branch is that no-database mode. With a database configured the
    /// store is never written here, so there is only ever one record of a plan.
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<TransportPlan>> Create(
        [FromBody] TransportPlanInput input,
        [FromServices] ITransportPlanService? plans,
        CancellationToken ct)
    {
        if (plans is null || reads is null) return store.CreatePlan(input);

        var created = await plans.CreateAsync(ToHeader(input), ct);

        // Read back through the same projection every other endpoint uses, so
        // the response is the shape the client already knows — carrying the
        // currentVersion the next mutation will have to send.
        var plan = await reads.PlanAsync(created.PlanKey, ct);
        return plan is null ? NotFound() : plan;
    }

    /// <summary>
    /// The client's shape into the service's. Two conversions, both of which
    /// exist because the wire format was fixed before the database was:
    /// <c>rt-RT-NORTH-01</c> carries a prefix the read path adds for the client's
    /// benefit, and the delivery date travels as a plain string.
    /// </summary>
    private static PlanHeaderInput ToHeader(TransportPlanInput input)
    {
        var routeId = (input?.RouteId ?? "").Trim();
        var routeCode = routeId.StartsWith("rt-", StringComparison.OrdinalIgnoreCase)
            ? routeId[3..]
            : routeId;

        // Exact, and deliberately not DateOnly.TryParse. The loose parser is
        // culture-dependent: it reads "11/09/2026" happily and silently decides
        // whether that is September or November. A delivery date two months out
        // is not a parse error anyone would notice — it is a lorry sent on the
        // wrong day — and the contract has always said YYYY-MM-DD.
        if (!DateOnly.TryParseExact(
                input?.DeliveryDate, "yyyy-MM-dd",
                CultureInfo.InvariantCulture, DateTimeStyles.None, out var deliveryDate))
        {
            throw new DomainException("วันที่ส่งไม่ถูกต้อง — ต้องเป็นรูปแบบ YYYY-MM-DD");
        }

        return new PlanHeaderInput(deliveryDate, routeCode, input?.Note);
    }

    /// <summary>
    /// Edits a draft plan's header — delivery date, route and note.
    ///
    /// <b>If-Match is required.</b> The value is the <c>currentVersion</c> the
    /// client read off the plan; two dispatchers with the same plan open would
    /// otherwise overwrite one another, and the second edit would win silently.
    ///
    /// What the plan is holding is not changed here — that is <c>{id}/stops</c>.
    /// The warehouse in the body is ignored on the SQL path for the same reason
    /// it is on create.
    /// </summary>
    [HttpPut("{id}")]
    public async Task<ActionResult<TransportPlan>> Update(
        string id,
        [FromBody] TransportPlanInput input,
        [FromServices] ITransportPlanService? plans,
        CancellationToken ct)
    {
        if (plans is null || reads is null) return store.UpdatePlan(id, input);

        // Passed through as sent — quoting and W/ prefixes included. Reading it
        // is DocumentIdentity's job; a second parser here would be a second
        // opinion on what counts as a version.
        var ifMatch = Request.Headers.IfMatch.ToString();

        await plans.UpdateAsync(id, ToHeader(input), ifMatch, ct);

        var plan = await reads.PlanAsync(id, ct);
        return plan is null ? NotFound() : plan;
    }

    /// <summary>
    /// Replaces the plan's contents with exactly these orders — the tick-boxes on
    /// the planning screen. Anything dropped returns to the pending pool, because
    /// an order is only ever in one place.
    /// </summary>
    [HttpPut("{id}/stops")]
    public ActionResult<TransportPlan> SetStops(string id, [FromBody] SetStopsRequest body) =>
        store.SetPlanStops(id, body?.StopIds ?? []);

    /// <summary>Cuts a draft manifest from the plan; the plan becomes `issued`.</summary>
    [HttpPost("{id}/issue")]
    public ActionResult<PlanIssueResult> Issue(string id) => store.IssuePlan(id);

    /// <summary>Drops the plan and returns everything in it to the pending pool.</summary>
    [HttpPost("{id}/cancel")]
    public ActionResult<TransportPlan> Cancel(string id) => store.CancelPlan(id);

    /// <summary>
    /// Raises a cancelled plan again as a fresh draft carrying the same header
    /// and whatever of its load is still unplanned.
    /// </summary>
    [HttpPost("{id}/recreate")]
    public ActionResult<PlanRecreateResult> Recreate(string id) => store.RecreatePlan(id);

    /// <summary>
    /// Removes the plan outright — for one raised by mistake. Only before a
    /// manifest has been cut from it; after that the plan is the record of how
    /// that document came about.
    /// </summary>
    [HttpDelete("{id}")]
    public IActionResult Delete(string id) { store.DeletePlan(id); return NoContent(); }
}
