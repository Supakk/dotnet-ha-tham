using Microsoft.EntityFrameworkCore;

namespace Mammod.Database.Documents;

/// <summary>
/// Loading and saving แผนขนส่ง. Persistence only — the rules live in the policy
/// and the transaction lives in the service.
///
/// Warehouse-scoped by the implementation, never by a parameter, for the same
/// reason <see cref="ShipmentRepository"/> is: a caller cannot forget a scope it
/// was never asked for, and cannot pass one that arrived in a request body.
///
/// Writes ask for tracking explicitly. <see cref="AppDbContext"/> is
/// <c>NoTracking</c> by default, and a mutation that forgets to opt in writes
/// nothing at all while still answering 200 — see the note on that class.
/// </summary>
public sealed class TransportPlanRepository(
    AppDbContext db, IWarehouseContext warehouse, IActorContext actor) : ITransportPlanRepository
{
    private string Whse => warehouse.CurrentWarehouseId;

    public Task<TransportPlanRow?> GetAsync(string planKey, CancellationToken ct = default) =>
        db.Set<TransportPlanRow>()
            .AsTracking()
            .FirstOrDefaultAsync(p => p.WhseId == Whse && p.PlanKey == planKey, ct);

    /// <summary>
    /// With lines, for issuing — where how many orders the plan is holding is a
    /// rule rather than a display detail.
    /// </summary>
    public Task<TransportPlanRow?> GetWithLinesAsync(string planKey, CancellationToken ct = default) =>
        db.Set<TransportPlanRow>()
            .AsTracking()
            .Include(p => p.Lines)
            .FirstOrDefaultAsync(p => p.WhseId == Whse && p.PlanKey == planKey, ct);

    /// <summary>Newest first — the numbers run in order, so the key sorts as the date does.</summary>
    public async Task<IReadOnlyList<TransportPlanRow>> ListAsync(CancellationToken ct = default) =>
        await db.Set<TransportPlanRow>()
            .Where(p => p.WhseId == Whse)
            .OrderByDescending(p => p.PlanKey)
            .ToListAsync(ct);

    /// <summary>
    /// Stamps the warehouse rather than trusting the caller to have set it: a row
    /// inserted with a blank WHSEID would be invisible to every read afterwards.
    /// </summary>
    public async Task AddAsync(TransportPlanRow plan, CancellationToken ct = default)
    {
        plan.WhseId = Whse;
        await db.Set<TransportPlanRow>().AddAsync(plan, ct);
    }

    /// <summary>
    /// Makes the plan hold exactly these orders, and nothing else.
    ///
    /// <b>An order leaves a plan by having its line cancelled, never deleted.</b>
    /// That is not a preference — it is what the rest of the system already
    /// assumes. <c>UX_DOC_TRANSPORT_PLAN_LINE_ORDER</c> is unique on ORDERKEY
    /// <i>filtered</i> to <c>STATUS &lt;&gt; 'CANCELLED'</c>, and a filter like that
    /// only earns its keep if cancelled rows stay: delete on removal and a plain
    /// unique index would do. <see cref="DeliveryOrderQuery"/> derives the
    /// pending pool the same way and says so outright — "claimed means a row
    /// whose own status is not CANCELLED, the same predicate as the two filtered
    /// unique indexes, so this query and the database constraint can never
    /// disagree". And the plan read filters <c>l.Status != CANCELLED</c>, which
    /// would be dead code against a table that deletes.
    ///
    /// So returning an order to the pool is not an action anybody performs. It
    /// is what cancelling the line <i>means</i>: the pool is a question, and a
    /// cancelled line stops being an answer to it.
    ///
    /// <b>Re-adding revives.</b> The primary key is
    /// <c>(WHSEID, PLANKEY, ORDERKEY)</c>, so a plan can never hold two rows for
    /// one order — putting back something taken out earlier has to bring the
    /// original row back to life rather than insert beside it. The history of
    /// that order on this plan is one row, whatever it has been through.
    /// </summary>
    public async Task ReplaceLinesAsync(
        string planKey, IReadOnlyList<string> orderKeys, CancellationToken ct = default)
    {
        var plan = await GetWithLinesAsync(planKey, ct)
            ?? throw new InvalidOperationException(
                $"ReplaceLinesAsync เรียกกับแผนที่ไม่มีอยู่: {planKey}");

        var wanted = new HashSet<string>(orderKeys, StringComparer.Ordinal);
        var now = DateTime.UtcNow;
        var who = actor.CurrentUser;

        foreach (var line in plan.Lines)
        {
            var keep = wanted.Remove(line.OrderKey);

            if (keep && line.Status == PlanStatus.Cancelled)
            {
                line.Status = LineActive;      // taken out earlier, put back now
                Stamp(line, now, who);
            }
            else if (!keep && line.Status != PlanStatus.Cancelled)
            {
                line.Status = PlanStatus.Cancelled;
                Stamp(line, now, who);
            }
        }

        // Whatever is left never had a row on this plan at all.
        foreach (var orderKey in wanted)
        {
            plan.Lines.Add(new TransportPlanLineRow
            {
                WhseId = Whse,
                PlanKey = plan.PlanKey,
                OrderKey = orderKey,
                Status = LineActive,
                AddDate = now,
                AddWho = who,
            });
        }
    }

    /// <summary>
    /// A live line. The document tables spell this <c>NEW</c> — it is what every
    /// seeded DOC_SHIPMENT_DETAIL and DOC_SHIPMENT_STOP row carries — and there
    /// is no check constraint narrowing it further. Only the distinction from
    /// CANCELLED carries meaning: that is the predicate the filtered indexes, the
    /// pool query and the read path all key on.
    /// </summary>
    private const string LineActive = "NEW";

    private static void Stamp(TransportPlanLineRow line, DateTime now, string who)
    {
        line.EditDate = now;
        line.EditWho = who;
    }
}
