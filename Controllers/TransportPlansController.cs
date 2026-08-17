using Mammod.Data;
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
public sealed class TransportPlansController(TmsStore store) : ControllerBase
{
    [HttpGet]
    public ActionResult<List<TransportPlan>> List() => store.ListPlans();

    [HttpPost]
    public ActionResult<TransportPlan> Create([FromBody] TransportPlanInput input) =>
        store.CreatePlan(input);

    [HttpPut("{id}")]
    public ActionResult<TransportPlan> Update(string id, [FromBody] TransportPlanInput input) =>
        store.UpdatePlan(id, input);

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
