namespace Mammod.Database.Documents;

/// <summary>
/// Every rule about when a แผนขนส่ง may change, in one place and with no I/O.
///
/// As with <see cref="ShipmentPolicy"/>, none of these rules is new. Each was an
/// <c>AssertPlanStatus(current, [...], "…")</c> beside its mutation in
/// <see cref="Mammod.Data.TmsStore"/>, and each method below names the line it
/// came from so the two can be compared rather than trusted.
///
/// A plan's life is short and mostly one-way: it is a draft until it becomes a
/// manifest, and after that it is a record of how that document came about. That
/// is why almost everything here is DRAFT-only — once a plan has issued, editing
/// it would rewrite the account of something that already happened.
/// </summary>
public sealed class TransportPlanPolicy : ITransportPlanPolicy
{
    /// <summary>TmsStore.UpdatePlan — draft only.</summary>
    public PolicyResult CanEdit(TransportPlanRow plan) =>
        Require(plan, "แก้ไข", PlanStatus.Draft);

    /// <summary>TmsStore.SetPlanStops — draft only.</summary>
    public PolicyResult CanSetStops(TransportPlanRow plan) =>
        Require(plan, "แก้ไขรายการในแผน", PlanStatus.Draft);

    /// <summary>
    /// TmsStore.IssuePlan — draft, and holding something.
    ///
    /// The count is a rule rather than a detail: a manifest cut from an empty
    /// plan is a lorry booked to carry nothing, and the mistake is only visible
    /// once the document has a number.
    /// </summary>
    public PolicyResult CanIssue(TransportPlanRow plan, int stopCount)
    {
        var state = Require(plan, "สร้างใบขนส่ง", PlanStatus.Draft);
        if (!state.IsAllowed) return state;

        return stopCount > 0
            ? PolicyResult.Allow()
            : PolicyResult.Incomplete("แผนนี้ยังไม่มีรายการ — เพิ่มใบสั่งส่งก่อน");
    }

    /// <summary>
    /// TmsStore.CancelPlan — draft only.
    ///
    /// <paramref name="currentShipment"/> is part of the contract because a plan
    /// that has issued points at a live document, and cancelling the plan under
    /// it would orphan the manifest. Today the status check already excludes
    /// that case — only a draft can be cancelled, and a draft has issued nothing
    /// — so the shipment is checked as a second, explicit guard rather than
    /// relied upon: if ISSUED ever becomes cancellable, this is where the
    /// question is already being asked.
    /// </summary>
    public PolicyResult CanCancel(TransportPlanRow plan, ShipmentRow? currentShipment)
    {
        var state = Require(plan, "ยกเลิก", PlanStatus.Draft);
        if (!state.IsAllowed) return state;

        return currentShipment is null
            ? PolicyResult.Allow()
            : PolicyResult.WrongState(
                $"ยกเลิกไม่ได้ เพราะแผนนี้ออกใบปิดบรรทุก {currentShipment.ShipmentKey} ไปแล้ว");
    }

    /// <summary>
    /// TmsStore.DeletePlan — draft or cancelled.
    ///
    /// Wider than cancel on purpose: delete is for a plan raised by mistake,
    /// and a plan that was cancelled properly can still be tidied away
    /// afterwards. A plan that issued cannot, because it is the record of where
    /// a real manifest came from.
    /// </summary>
    public PolicyResult CanDelete(TransportPlanRow plan) =>
        Require(plan, "ลบ", PlanStatus.Draft, PlanStatus.Cancelled);

    /// <summary>
    /// The refusal names the status the user is looking at, in the words the
    /// screen uses — the same sentence TmsStore.AssertPlanStatus produced.
    /// </summary>
    private static PolicyResult Require(TransportPlanRow plan, string action, params string[] allowed) =>
        allowed.Contains(plan.Status)
            ? PolicyResult.Allow()
            : PolicyResult.WrongState($"{action}ไม่ได้ เพราะแผนอยู่สถานะ \"{Label(plan.Status)}\"");

    private static string Label(string status) =>
        Mammod.Models.TransportPlanStatus.Label.TryGetValue(status.ToLowerInvariant(), out var label)
            ? label
            : status;
}
